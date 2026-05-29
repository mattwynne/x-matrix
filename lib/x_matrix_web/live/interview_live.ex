defmodule XMatrixWeb.InterviewLive do
  use XMatrixWeb, :live_view

  alias XMatrix.Strategies

  @element_stages [:true_north, :aspiration, :strategy, :evidence, :tactic]

  @correlation_pairs %{
    "strategy_aspiration" => {:strategies, :aspirations},
    "evidence_aspiration" => {:evidence, :aspirations},
    "tactic_strategy" => {:tactics, :strategies},
    "tactic_evidence" => {:tactics, :evidence}
  }

  @strength_options [
    {"No connection", "none"},
    {"Weak", "weak"},
    {"Medium", "medium"},
    {"Strong", "strong"}
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    strategy = Strategies.get_strategy!(id)

    if strategy.status == :complete do
      {:ok, push_navigate(socket, to: ~p"/strategies/#{strategy.id}")}
    else
      {:ok, load(socket, id)}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, draft} =
      Strategies.create_draft_strategy(%{
        title: "Untitled strategy",
        current_step: "chat:true_north",
        ai_assisted: default_ai_assisted?()
      })

    {:ok, push_navigate(socket, to: ~p"/interview/#{draft.id}")}
  end

  @impl true
  def handle_event("submit_message", %{"message" => %{"content" => content}}, socket) do
    content = String.trim(content || "")

    if content == "" do
      {:noreply, socket}
    else
      stage = socket.assigns.stage
      ai_assisted? = socket.assigns.effective_ai_assisted

      {:ok, _message} = Strategies.add_message(socket.assigns.strategy, :user, content)

      socket =
        if ai_assisted? do
          socket
        else
          persist_stage_element(socket, stage, content, nil)
        end

      socket = facilitator_turn(socket)
      {:noreply, load(socket, socket.assigns.strategy.id, socket.assigns.pending_proposals)}
    end
  end

  def handle_event("toggle_ai", _params, socket) do
    {:ok, strategy} =
      Strategies.update_strategy(socket.assigns.strategy, %{
        ai_assisted: not socket.assigns.strategy.ai_assisted
      })

    {:noreply, load(assign(socket, :strategy, strategy), strategy.id)}
  end

  def handle_event("add_message_as_element", %{"id" => id}, socket) do
    message = Enum.find(socket.assigns.messages, &(to_string(&1.id) == id))

    socket =
      if message do
        persist_stage_element(socket, socket.assigns.stage, message.content, nil)
      else
        socket
      end

    {:noreply, load(socket, socket.assigns.strategy.id)}
  end

  def handle_event("add_proposal", %{"id" => id}, socket) do
    {proposal, proposals} = pop_proposal(socket.assigns.pending_proposals, id)

    socket =
      if proposal do
        persist_stage_element(socket, proposal.type, proposal.title, proposal.description)
      else
        socket
      end

    {:noreply, load(socket, socket.assigns.strategy.id, proposals)}
  end

  def handle_event("dismiss_proposal", %{"id" => id}, socket) do
    {_proposal, proposals} = pop_proposal(socket.assigns.pending_proposals, id)
    {:noreply, assign(socket, :pending_proposals, proposals)}
  end

  def handle_event("edit_proposal", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_proposal_id, id)}
  end

  def handle_event("save_proposal_edit", %{"proposal_id" => id, "proposal" => attrs}, socket) do
    {proposal, proposals} = pop_proposal(socket.assigns.pending_proposals, id)

    socket =
      if proposal do
        persist_stage_element(
          socket,
          proposal.type,
          Map.get(attrs, "title", proposal.title),
          Map.get(attrs, "description", proposal.description)
        )
      else
        socket
      end

    {:noreply, load(socket, socket.assigns.strategy.id, proposals)}
  end

  def handle_event("move_on", _params, socket) do
    {:noreply, goto(socket, next_on_spine(socket.assigns.step, socket.assigns))}
  end

  def handle_event("back", _params, socket) do
    {:noreply, goto(socket, prev_on_spine(socket.assigns.step, socket.assigns))}
  end

  def handle_event("save_source", params, socket) do
    strategy = socket.assigns.strategy
    [_, "src", _key, src_id] = String.split(socket.assigns.step, ":")
    source = Enum.find(all_elements(socket.assigns), &(to_string(&1.id) == src_id))
    by_id = Map.new(all_elements(socket.assigns), &{to_string(&1.id), &1})

    for {target_id, strength} <- Map.get(params, "corr", %{}), source do
      target = Map.fetch!(by_id, target_id)
      Strategies.upsert_correlation(strategy, source, target, String.to_existing_atom(strength))
    end

    socket = load(socket, strategy.id)
    {:noreply, goto(socket, next_on_spine(socket.assigns.step, socket.assigns))}
  end

  def handle_event("next", _params, socket) do
    {:noreply, goto(socket, next_on_spine(socket.assigns.step, socket.assigns))}
  end

  def handle_event("finish", _params, socket) do
    {:ok, strategy} = Strategies.complete_strategy(socket.assigns.strategy)
    {:noreply, push_navigate(socket, to: ~p"/strategies/#{strategy.id}")}
  end

  defp load(socket, id, pending_proposals \\ []) do
    strategy = Strategies.get_strategy!(id)
    step = sanitize_step(strategy.current_step || "chat:true_north")
    stage = stage_from_step(step)

    socket
    |> assign(:strategy, strategy)
    |> assign(:step, step)
    |> assign(:stage, stage)
    |> assign(:messages, Strategies.list_messages(strategy))
    |> assign(:true_north, Strategies.elements_by_type(strategy, :true_north))
    |> assign(:aspirations, Strategies.elements_by_type(strategy, :aspiration))
    |> assign(:strategies, Strategies.elements_by_type(strategy, :strategy))
    |> assign(:evidence, Strategies.elements_by_type(strategy, :evidence))
    |> assign(:tactics, Strategies.elements_by_type(strategy, :tactic))
    |> assign(:pending_proposals, pending_proposals)
    |> assign(:editing_proposal_id, nil)
    |> assign(:fallback_notice, fallback_notice(strategy))
    |> assign(:effective_ai_assisted, effective_ai_assisted?(strategy))
    |> ensure_opening_prompt()
  end

  defp ensure_opening_prompt(%{assigns: %{messages: [], stage: stage}} = socket)
       when stage in @element_stages do
    {:ok, reply} = XMatrix.LLM.Scripted.facilitate(stage, [], snapshot(socket.assigns))
    {:ok, _} = Strategies.add_message(socket.assigns.strategy, :assistant, reply.message)
    assign(socket, :messages, Strategies.list_messages(socket.assigns.strategy))
  end

  defp ensure_opening_prompt(socket), do: socket

  defp facilitator_turn(socket) do
    adapter = adapter_for(socket.assigns.strategy)
    messages = Strategies.list_messages(socket.assigns.strategy)
    conversation = Enum.map(messages, &%{role: &1.role, content: &1.content})

    case adapter.facilitate(socket.assigns.stage, conversation, snapshot(socket.assigns)) do
      {:ok, reply} ->
        {:ok, _} = Strategies.add_message(socket.assigns.strategy, :assistant, reply.message)

        assign(
          socket,
          :pending_proposals,
          normalize_proposals(reply.proposals, socket.assigns.stage)
        )

      {:error, _reason} ->
        {:ok, reply} =
          XMatrix.LLM.Scripted.facilitate(
            socket.assigns.stage,
            conversation,
            snapshot(socket.assigns)
          )

        {:ok, _} = Strategies.add_message(socket.assigns.strategy, :assistant, reply.message)

        socket
        |> put_flash(
          :info,
          "The AI facilitator was unavailable, so we switched to the free scripted guide."
        )
        |> assign(:pending_proposals, [])
    end
  end

  defp persist_stage_element(socket, :true_north, title, description) do
    case List.first(socket.assigns.true_north) do
      nil ->
        {:ok, _} =
          Strategies.add_element(socket.assigns.strategy, %{
            element_type: :true_north,
            title: title,
            description: description
          })

      element ->
        {:ok, _} = Strategies.update_element(element, %{title: title, description: description})
    end

    socket
  end

  defp persist_stage_element(socket, stage, title, description) when stage in @element_stages do
    {:ok, _} =
      Strategies.add_element(socket.assigns.strategy, %{
        element_type: stage,
        title: title,
        description: description
      })

    socket
  end

  defp normalize_proposals(proposals, fallback_type) do
    proposals
    |> Enum.map(fn proposal ->
      %{
        id: Ecto.UUID.generate(),
        type: normalize_stage(Map.get(proposal, :type), fallback_type),
        title: Map.get(proposal, :title, ""),
        description: Map.get(proposal, :description)
      }
    end)
    |> Enum.filter(&(&1.title != ""))
  end

  defp pop_proposal(proposals, id) do
    proposal = Enum.find(proposals, &(&1.id == id))
    {proposal, Enum.reject(proposals, &(&1.id == id))}
  end

  defp goto(socket, step) do
    {:ok, strategy} = Strategies.set_step(socket.assigns.strategy, step)
    load(assign(socket, :strategy, strategy), strategy.id)
  end

  defp spine(assigns) do
    chat_steps = Enum.map(@element_stages, &"chat:#{&1}")

    correlation_steps =
      Enum.flat_map(
        ["strategy_aspiration", "evidence_aspiration", "tactic_strategy", "tactic_evidence"],
        fn key ->
          {src_key, _} = @correlation_pairs[key]
          sources = Map.fetch!(assigns, src_key)
          ["corr:intro:#{key}" | Enum.map(sources, &"corr:src:#{key}:#{&1.id}")]
        end
      )

    chat_steps ++ correlation_steps ++ ["review"]
  end

  defp next_on_spine(step, assigns) do
    line = spine(assigns)
    i = Enum.find_index(line, &(&1 == step)) || 0
    Enum.at(line, min(i + 1, length(line) - 1))
  end

  defp prev_on_spine(step, assigns) do
    line = spine(assigns)
    i = Enum.find_index(line, &(&1 == step)) || 0
    Enum.at(line, max(i - 1, 0))
  end

  defp sanitize_step("true_north"), do: "chat:true_north"
  defp sanitize_step("welcome"), do: "chat:true_north"
  defp sanitize_step("name"), do: "chat:true_north"
  defp sanitize_step("tn_statement"), do: "chat:true_north"
  defp sanitize_step("tn_why"), do: "chat:true_north"
  defp sanitize_step("elem:" <> _), do: "chat:aspiration"

  defp sanitize_step("chat:" <> stage = step) do
    if normalize_stage(stage, nil), do: step, else: "chat:true_north"
  end

  defp sanitize_step("corr:intro:" <> key = step) do
    if Map.has_key?(@correlation_pairs, key), do: step, else: "chat:true_north"
  end

  defp sanitize_step("corr:src:" <> rest = step) do
    case String.split(rest, ":") do
      [key, _id] -> if Map.has_key?(@correlation_pairs, key), do: step, else: "chat:true_north"
      _ -> "chat:true_north"
    end
  end

  defp sanitize_step("review"), do: "review"
  defp sanitize_step(_step), do: "chat:true_north"

  defp stage_from_step("chat:" <> stage), do: normalize_stage(stage, :true_north)
  defp stage_from_step(_), do: nil

  defp normalize_stage(stage, _fallback) when is_atom(stage) and stage in @element_stages,
    do: stage

  defp normalize_stage(stage, fallback) when is_binary(stage) do
    Enum.find(@element_stages, fallback, &(to_string(&1) == stage))
  end

  defp normalize_stage(_stage, fallback), do: fallback

  defp chat_stage?(stage), do: stage in @element_stages

  defp all_elements(assigns) do
    assigns.true_north ++
      assigns.aspirations ++ assigns.strategies ++ assigns.evidence ++ assigns.tactics
  end

  defp snapshot(assigns) do
    %{
      true_north: Enum.map(assigns.true_north, &element_snapshot/1),
      aspirations: Enum.map(assigns.aspirations, &element_snapshot/1),
      strategies: Enum.map(assigns.strategies, &element_snapshot/1),
      evidence: Enum.map(assigns.evidence, &element_snapshot/1),
      tactics: Enum.map(assigns.tactics, &element_snapshot/1)
    }
  end

  defp element_snapshot(element) do
    %{title: element.title, description: element.description}
  end

  defp adapter_for(%{ai_assisted: false}), do: XMatrix.LLM.Scripted

  defp adapter_for(%{ai_assisted: true}) do
    if openrouter_key?() do
      Application.get_env(:x_matrix, :llm_adapter, XMatrix.LLM.OpenRouter)
    else
      XMatrix.LLM.Scripted
    end
  end

  defp fallback_notice(%{ai_assisted: true}) do
    if openrouter_key?(),
      do: nil,
      else: "No OpenRouter API key is configured, so this draft is using the free scripted guide."
  end

  defp fallback_notice(_strategy), do: nil

  defp effective_ai_assisted?(%{ai_assisted: true}), do: openrouter_key?()
  defp effective_ai_assisted?(_strategy), do: false

  defp openrouter_key? do
    case Application.get_env(:x_matrix, :openrouter_api_key) do
      key when is_binary(key) -> String.trim(key) != ""
      _ -> false
    end
  end

  defp default_ai_assisted?, do: openrouter_key?()

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%= if chat_stage?(@stage) do %>
        <.chat_interview
          strategy={@strategy}
          stage={@stage}
          messages={@messages}
          pending_proposals={@pending_proposals}
          editing_proposal_id={@editing_proposal_id}
          fallback_notice={@fallback_notice}
          effective_ai_assisted={@effective_ai_assisted}
          true_north={@true_north}
          aspirations={@aspirations}
          strategies={@strategies}
          evidence={@evidence}
          tactics={@tactics}
        />
      <% else %>
        <div class="mx-auto max-w-2xl">
          {render_step(assigns)}
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  attr :strategy, :map, required: true
  attr :stage, :atom, required: true
  attr :messages, :list, required: true
  attr :pending_proposals, :list, required: true
  attr :editing_proposal_id, :string, default: nil
  attr :fallback_notice, :string, default: nil
  attr :effective_ai_assisted, :boolean, required: true
  attr :true_north, :list, required: true
  attr :aspirations, :list, required: true
  attr :strategies, :list, required: true
  attr :evidence, :list, required: true
  attr :tactics, :list, required: true

  defp chat_interview(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 py-8">
      <.taste_progress stage={@stage} />

      <div
        :if={@fallback_notice}
        class="mt-4 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900"
      >
        {@fallback_notice}
      </div>

      <div class="mt-6 grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <section class="rounded-3xl border border-slate-200 bg-white shadow-sm">
          <div class="flex items-center justify-between border-b border-slate-200 px-5 py-4">
            <div>
              <p class="text-sm font-semibold uppercase tracking-wide text-indigo-700">
                {stage_label(@stage)}
              </p>
              <h1 class="text-2xl font-bold text-slate-950">Conversational interview</h1>
            </div>
            <button
              id="ai-toggle"
              type="button"
              phx-click="toggle_ai"
              class="rounded-full border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700 transition hover:border-indigo-400 hover:text-indigo-700"
            >
              AI {(@strategy.ai_assisted && "ON") || "OFF"}
            </button>
          </div>

          <div id="interview-transcript" class="max-h-[34rem] space-y-4 overflow-y-auto px-5 py-5">
            <article
              :for={message <- @messages}
              id={"message-#{message.id}"}
              class={[
                "rounded-2xl px-4 py-3",
                message.role == :assistant && "mr-10 bg-indigo-50 text-indigo-950",
                message.role == :user && "ml-10 bg-slate-900 text-white"
              ]}
            >
              <p class="text-xs font-semibold uppercase tracking-wide opacity-70">{message.role}</p>
              <p class="mt-1 whitespace-pre-wrap">{message.content}</p>
              <button
                :if={message.role == :user and @effective_ai_assisted}
                type="button"
                phx-click="add_message_as_element"
                phx-value-id={message.id}
                class="mt-3 rounded-full bg-white/90 px-3 py-1 text-sm font-semibold text-slate-900 transition hover:bg-indigo-100"
              >
                Add my answer
              </button>
            </article>

            <.proposal_cards proposals={@pending_proposals} editing_id={@editing_proposal_id} />
          </div>

          <form id="chat-form" phx-submit="submit_message" class="border-t border-slate-200 p-5">
            <.input
              id="chat-content"
              name="message[content]"
              type="textarea"
              label="Your answer"
              rows="3"
              value=""
              placeholder={placeholder(@stage, @effective_ai_assisted)}
            />
            <div class="mt-4 flex items-center justify-between gap-3">
              <button
                type="button"
                phx-click="move_on"
                class="rounded-xl border border-slate-300 px-4 py-2 font-semibold text-slate-700 transition hover:bg-slate-50"
              >
                Move on
              </button>
              <button class="rounded-xl bg-indigo-700 px-5 py-2 font-semibold text-white transition hover:bg-indigo-800">
                Send
              </button>
            </div>
          </form>
        </section>

        <.emerging_matrix
          true_north={@true_north}
          aspirations={@aspirations}
          strategies={@strategies}
          evidence={@evidence}
          tactics={@tactics}
        />
      </div>
    </div>
    """
  end

  attr :stage, :atom, required: true

  defp taste_progress(assigns) do
    stages = [
      {:true_north, "True North"},
      {:aspiration, "Aspirations"},
      {:strategy, "Strategies"},
      {:evidence, "Evidence"},
      {:tactic, "Tactics"},
      {:relationships, "Relationships"},
      {:review, "Review"}
    ]

    assigns = assign(assigns, :stages, stages)

    ~H"""
    <nav id="taste-progress" class="flex flex-wrap gap-2" aria-label="Interview progress">
      <span
        :for={{key, label} <- @stages}
        class={[
          "rounded-full px-3 py-1 text-sm font-semibold",
          key == @stage && "bg-indigo-700 text-white",
          key != @stage && "bg-slate-100 text-slate-600"
        ]}
      >
        {label}
      </span>
    </nav>
    """
  end

  attr :true_north, :list, required: true
  attr :aspirations, :list, required: true
  attr :strategies, :list, required: true
  attr :evidence, :list, required: true
  attr :tactics, :list, required: true

  defp emerging_matrix(assigns) do
    ~H"""
    <aside id="emerging-matrix" class="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
      <h2 class="text-lg font-bold text-slate-950">Emerging matrix</h2>
      <p class="mt-1 text-sm text-slate-500">Only confirmed items appear here.</p>
      <div class="mt-5 space-y-5">
        <.matrix_group title="True North" items={@true_north} />
        <.matrix_group title="Aspirations" items={@aspirations} />
        <.matrix_group title="Strategies" items={@strategies} />
        <.matrix_group title="Evidence" items={@evidence} />
        <.matrix_group title="Tactics" items={@tactics} />
      </div>
    </aside>
    """
  end

  attr :title, :string, required: true
  attr :items, :list, required: true

  defp matrix_group(assigns) do
    ~H"""
    <section>
      <h3 class="text-sm font-semibold uppercase tracking-wide text-slate-500">{@title}</h3>
      <p :if={@items == []} class="mt-2 text-sm text-slate-400">Nothing confirmed yet.</p>
      <ul :if={@items != []} class="mt-2 space-y-2">
        <li :for={item <- @items} class="rounded-xl bg-slate-50 px-3 py-2 text-sm text-slate-800">
          <span class="font-semibold">{item.title}</span>
          <span :if={item.description} class="mt-1 block text-slate-500">{item.description}</span>
        </li>
      </ul>
    </section>
    """
  end

  attr :proposals, :list, required: true
  attr :editing_id, :string, default: nil

  defp proposal_cards(assigns) do
    ~H"""
    <div
      :for={proposal <- @proposals}
      id={"proposal-#{proposal.id}"}
      class="proposal-card mr-10 rounded-2xl border border-indigo-200 bg-white p-4 shadow-sm"
    >
      <p class="text-xs font-semibold uppercase tracking-wide text-indigo-700">Suggestion</p>
      <%= if @editing_id == proposal.id do %>
        <form id={"proposal-edit-form-#{proposal.id}"} phx-submit="save_proposal_edit">
          <input type="hidden" name="proposal_id" value={proposal.id} />
          <.input name="proposal[title]" label="Title" value={proposal.title} />
          <.input name="proposal[description]" label="Description" value={proposal.description || ""} />
          <button class="mt-3 rounded-lg bg-indigo-700 px-4 py-2 text-sm font-semibold text-white">
            Save and add
          </button>
        </form>
      <% else %>
        <p class="mt-1 font-semibold text-slate-950">{proposal.title}</p>
        <p :if={proposal.description} class="mt-1 text-sm text-slate-500">{proposal.description}</p>
        <div class="mt-3 flex gap-2">
          <button
            type="button"
            phx-click="add_proposal"
            phx-value-id={proposal.id}
            class="rounded-lg bg-indigo-700 px-3 py-1.5 text-sm font-semibold text-white"
          >
            Add
          </button>
          <button
            type="button"
            phx-click="edit_proposal"
            phx-value-id={proposal.id}
            class="rounded-lg border border-slate-300 px-3 py-1.5 text-sm font-semibold text-slate-700"
          >
            Edit
          </button>
          <button
            type="button"
            phx-click="dismiss_proposal"
            phx-value-id={proposal.id}
            class="rounded-lg px-3 py-1.5 text-sm font-semibold text-slate-500"
          >
            Dismiss
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_step(%{step: "corr:intro:" <> key} = assigns) do
    assigns = assign(assigns, :copy, correlation_intro(key))

    ~H"""
    <h1 class="text-3xl font-bold text-slate-950">{corr_label(@step)}</h1>
    <div class="mt-4 space-y-3 text-slate-600">
      <p :for={para <- @copy}>{para}</p>
    </div>
    <.nav type="button" event="next" primary="Continue" />
    """
  end

  defp render_step(%{step: "corr:src:" <> rest} = assigns) do
    [key, src_id] = String.split(rest, ":")
    {src_key, tgt_key} = @correlation_pairs[key]
    source = Enum.find(Map.fetch!(assigns, src_key), &(to_string(&1.id) == src_id))
    targets = Map.fetch!(assigns, tgt_key)

    assigns =
      assign(assigns,
        key: key,
        source: source,
        targets: targets,
        strength_options: @strength_options
      )

    ~H"""
    <form phx-submit="save_source">
      <.question
        title={"How strongly does this relate to each #{tgt_singular(@key)}?"}
        hint="There's no need to force a connection. No connection is a perfectly good answer."
      />
      <p class="mb-4 rounded-lg bg-indigo-50 px-3 py-2 font-semibold text-indigo-900">
        {@source && @source.title}
      </p>

      <div class="space-y-3">
        <div :for={target <- @targets} class="flex flex-col gap-1">
          <label for={"corr-#{target.id}"} class="text-sm font-medium text-slate-700">
            {target.title}
          </label>
          <select
            id={"corr-#{target.id}"}
            name={"corr[#{target.id}]"}
            class="rounded-lg border border-slate-300 px-3 py-2"
          >
            <option
              :for={{label, value} <- @strength_options}
              value={value}
              selected={value == current_strength(@strategy, @source, target)}
            >
              {label}
            </option>
          </select>
        </div>
      </div>

      <.nav primary="Next" />
    </form>
    """
  end

  defp render_step(%{step: "review"} = assigns) do
    ~H"""
    <form phx-submit="finish">
      <h1 class="text-3xl font-bold text-slate-950">You've built your X-Matrix</h1>
      <p class="mt-3 text-slate-600">
        Finishing marks the strategy complete and shows it as a full X-Matrix.
      </p>
      <ul class="mt-4 grid grid-cols-2 gap-3 text-sm sm:grid-cols-3">
        <li class="rounded-lg border border-slate-200 p-3">True North: {length(@true_north)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Aspirations: {length(@aspirations)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Strategies: {length(@strategies)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Evidence: {length(@evidence)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Tactics: {length(@tactics)}</li>
      </ul>
      <.nav primary="Finish & view matrix" />
    </form>
    """
  end

  defp render_step(assigns) do
    ~H"""
    <p class="text-slate-600">Step content for {@step}.</p>
    """
  end

  attr :back, :boolean, default: true
  attr :primary, :string, required: true
  attr :type, :string, default: "submit"
  attr :event, :string, default: nil

  defp nav(assigns) do
    ~H"""
    <div class="mt-8 flex items-center justify-between gap-3">
      <button
        :if={@back}
        type="button"
        phx-click="back"
        class="rounded-lg border border-slate-300 px-4 py-2 font-medium text-slate-700 hover:bg-slate-50"
      >
        Back
      </button>
      <span :if={not @back}></span>
      <button
        type={@type}
        phx-click={@event}
        class="rounded-lg bg-indigo-700 px-5 py-2 font-semibold text-white hover:bg-indigo-800"
      >
        {@primary}
      </button>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :hint, :string, default: nil

  defp question(assigns) do
    ~H"""
    <h1 class="text-2xl font-bold text-slate-950">{@title}</h1>
    <p :if={@hint} class="mt-2 mb-4 text-slate-500">{@hint}</p>
    """
  end

  defp stage_label(:true_north), do: "True North"
  defp stage_label(:aspiration), do: "Aspirations"
  defp stage_label(:strategy), do: "Strategies"
  defp stage_label(:evidence), do: "Evidence"
  defp stage_label(:tactic), do: "Tactics"

  defp placeholder(:strategy, true),
    do: "Tell the facilitator what you are considering; use Add my answer to save it."

  defp placeholder(_stage, true), do: "Chat with the facilitator..."
  defp placeholder(stage, false), do: "Type one #{stage_label(stage)} item to add it..."

  defp corr_label("corr:intro:strategy_aspiration"), do: "Strategies → Aspirations"
  defp corr_label("corr:intro:evidence_aspiration"), do: "Evidence → Aspirations"
  defp corr_label("corr:intro:tactic_strategy"), do: "Tactics → Strategies"
  defp corr_label("corr:intro:tactic_evidence"), do: "Tactics → Evidence"

  defp tgt_singular(key) do
    {_, tgt_key} = @correlation_pairs[key]

    case tgt_key do
      :aspirations -> "aspiration"
      :strategies -> "strategy"
      :evidence -> "piece of evidence"
    end
  end

  defp correlation_intro("strategy_aspiration") do
    [
      "Now let's test how things connect. For each strategy, how strongly does it contribute to each aspiration?"
    ]
  end

  defp correlation_intro("evidence_aspiration") do
    ["For each piece of evidence, how strongly does it indicate progress toward each aspiration?"]
  end

  defp correlation_intro("tactic_strategy") do
    ["For each tactic, how strongly does it enact each strategy?"]
  end

  defp correlation_intro("tactic_evidence") do
    ["Finally, for each tactic, how strongly should it move each piece of evidence?"]
  end

  defp current_strength(_strategy, nil, _target), do: "none"

  defp current_strength(strategy, source, target) do
    case Enum.find(strategy.correlations, fn c ->
           c.source_element_id == source.id and c.target_element_id == target.id
         end) do
      nil -> "none"
      corr -> to_string(corr.strength)
    end
  end
end
