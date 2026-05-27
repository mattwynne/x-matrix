defmodule XMatrixWeb.InterviewLive do
  use XMatrixWeb, :live_view

  alias XMatrix.Strategies

  @steps ~w(true_north aspirations strategies strategy_aspiration evidence
            evidence_aspiration tactics tactic_strategy tactic_evidence review)

  @step_titles %{
    "true_north" => "True North",
    "aspirations" => "Aspirations",
    "strategies" => "Strategies",
    "strategy_aspiration" => "Strategies → Aspirations",
    "evidence" => "Evidence",
    "evidence_aspiration" => "Evidence → Aspirations",
    "tactics" => "Tactics",
    "tactic_strategy" => "Tactics → Strategies",
    "tactic_evidence" => "Tactics → Evidence",
    "review" => "Review"
  }

  @element_steps %{
    "true_north" => :true_north,
    "aspirations" => :aspiration,
    "strategies" => :strategy,
    "evidence" => :evidence,
    "tactics" => :tactic
  }

  @correlation_steps %{
    "strategy_aspiration" => {:strategies, :aspirations},
    "evidence_aspiration" => {:evidence, :aspirations},
    "tactic_strategy" => {:tactics, :strategies},
    "tactic_evidence" => {:tactics, :evidence}
  }

  @strength_options [{"—", "none"}, {"weak", "weak"}, {"medium", "medium"}, {"strong", "strong"}]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, load(socket, id)}
  end

  def mount(_params, _session, socket) do
    {:ok, draft} = Strategies.create_draft_strategy(%{title: "Untitled strategy"})
    {:ok, push_navigate(socket, to: ~p"/interview/#{draft.id}")}
  end

  @impl true
  def handle_event("next", _params, socket) do
    {:noreply, goto(socket, next_step(socket.assigns.step))}
  end

  def handle_event("back", _params, socket) do
    {:noreply, goto(socket, prev_step(socket.assigns.step))}
  end

  def handle_event("save_true_north", %{"title" => title, "element" => element}, socket) do
    {:ok, strategy} = Strategies.update_strategy(socket.assigns.strategy, %{title: title})

    if socket.assigns.true_north == [] and element["title"] not in [nil, ""] do
      {:ok, _} =
        Strategies.add_element(strategy, %{
          element_type: :true_north,
          title: element["title"],
          description: element["description"]
        })
    end

    {:noreply, load(socket, strategy.id)}
  end

  def handle_event("add_element", %{"element" => element}, socket) do
    type = @element_steps[socket.assigns.step]

    if element["title"] in [nil, ""] do
      {:noreply, socket}
    else
      {:ok, _} =
        Strategies.add_element(socket.assigns.strategy, %{
          element_type: type,
          title: element["title"],
          description: element["description"]
        })

      {:noreply, load(socket, socket.assigns.strategy.id)}
    end
  end

  def handle_event("delete_element", %{"id" => id}, socket) do
    element = Enum.find(all_elements(socket.assigns), &(to_string(&1.id) == id))
    if element, do: Strategies.delete_element(element)
    {:noreply, load(socket, socket.assigns.strategy.id)}
  end

  def handle_event("save_correlations", %{"corr" => pairs}, socket) do
    strategy = socket.assigns.strategy
    elements_by_id = Map.new(all_elements(socket.assigns), &{to_string(&1.id), &1})

    Enum.each(pairs, fn {key, strength} ->
      [src_id, tgt_id] = String.split(key, "_")
      source = Map.fetch!(elements_by_id, src_id)
      target = Map.fetch!(elements_by_id, tgt_id)
      Strategies.upsert_correlation(strategy, source, target, String.to_existing_atom(strength))
    end)

    {:noreply, goto(socket, next_step(socket.assigns.step))}
  end

  def handle_event("save_correlations", _params, socket) do
    {:noreply, goto(socket, next_step(socket.assigns.step))}
  end

  def handle_event("finish", _params, socket) do
    {:ok, strategy} = Strategies.complete_strategy(socket.assigns.strategy)
    {:noreply, push_navigate(socket, to: ~p"/strategies/#{strategy.id}")}
  end

  defp load(socket, id) do
    strategy = Strategies.get_strategy!(id)
    assign_strategy(socket, strategy)
  end

  defp assign_strategy(socket, strategy) do
    step = strategy.current_step || "true_north"

    socket
    |> assign(:strategy, strategy)
    |> assign(:step, step)
    |> assign(:step_title, @step_titles[step])
    |> assign(:step_number, index(step) + 1)
    |> assign(:step_count, length(@steps))
    |> assign(:first_step?, index(step) == 0)
    |> assign(:correlation_step?, Map.has_key?(@correlation_steps, step))
    |> assign(:true_north, Strategies.elements_by_type(strategy, :true_north))
    |> assign(:aspirations, Strategies.elements_by_type(strategy, :aspiration))
    |> assign(:strategies, Strategies.elements_by_type(strategy, :strategy))
    |> assign(:evidence, Strategies.elements_by_type(strategy, :evidence))
    |> assign(:tactics, Strategies.elements_by_type(strategy, :tactic))
  end

  defp goto(socket, step) do
    {:ok, strategy} = Strategies.set_step(socket.assigns.strategy, step)
    assign_strategy(socket, strategy)
  end

  defp next_step(step), do: Enum.at(@steps, min(index(step) + 1, length(@steps) - 1))
  defp prev_step(step), do: Enum.at(@steps, max(index(step) - 1, 0))
  defp index(step), do: Enum.find_index(@steps, &(&1 == step)) || 0

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="mx-auto max-w-3xl p-8">
        <p class="text-sm font-semibold uppercase tracking-wide text-indigo-700">
          Step {@step_number} of {@step_count}
        </p>
        <h1 class="mt-1 text-3xl font-bold text-slate-950">{@step_title}</h1>

        <div class="mt-6">
          {render_step(assigns)}
        </div>

        <div class="mt-8 flex justify-between">
          <button
            :if={not @first_step?}
            type="button"
            phx-click="back"
            class="rounded-lg border border-slate-300 px-4 py-2 font-medium text-slate-700"
          >
            Back
          </button>
          <span :if={@first_step?}></span>

          <button
            :if={@step != "review" and not @correlation_step?}
            type="button"
            phx-click="next"
            class="rounded-lg bg-indigo-700 px-4 py-2 font-semibold text-white"
          >
            Next
          </button>
        </div>
      </main>
    </Layouts.app>
    """
  end

  defp render_step(%{step: "true_north"} = assigns) do
    ~H"""
    <div class="space-y-6">
      <form phx-submit="save_true_north" id="true-north-form" class="space-y-4">
        <.input name="title" value={@strategy.title} label="Strategy name" />
        <.input
          :if={@true_north == []}
          name="element[title]"
          value=""
          label="True North"
          placeholder="The orienting direction"
        />
        <.input
          :if={@true_north == []}
          type="textarea"
          name="element[description]"
          value=""
          label="Description"
        />
        <button :if={@true_north == []} class="rounded-lg bg-slate-800 px-4 py-2 text-white">
          Save True North
        </button>
      </form>

      <ul class="space-y-2">
        <li :for={el <- @true_north} class="rounded-lg border border-slate-200 p-3">
          <span class="font-semibold">{el.title}</span>
        </li>
      </ul>
    </div>
    """
  end

  defp render_step(%{step: step} = assigns) when is_map_key(@element_steps, step) do
    assigns = assign(assigns, :items, items_for(assigns, step))

    ~H"""
    <div class="space-y-6">
      <form phx-submit="add_element" id="element-form" class="space-y-4">
        <.input name="element[title]" value="" label="Title" />
        <.input type="textarea" name="element[description]" value="" label="Description" />
        <button class="rounded-lg bg-slate-800 px-4 py-2 text-white">Add</button>
      </form>

      <ul class="space-y-2">
        <li
          :for={el <- @items}
          class="flex items-center justify-between rounded-lg border border-slate-200 p-3"
        >
          <span class="font-semibold">{el.title}</span>
          <button
            type="button"
            phx-click="delete_element"
            phx-value-id={el.id}
            class="text-sm text-red-600"
          >
            Remove {el.title}
          </button>
        </li>
      </ul>
    </div>
    """
  end

  defp render_step(%{step: step} = assigns) when is_map_key(@correlation_steps, step) do
    {rows_key, cols_key} = @correlation_steps[step]
    rows = Map.fetch!(assigns, rows_key)
    cols = Map.fetch!(assigns, cols_key)
    assigns = assign(assigns, rows: rows, cols: cols, strength_options: @strength_options)

    ~H"""
    <form phx-submit="save_correlations" id="correlation-form">
      <div class="overflow-x-auto">
        <table class="border-collapse">
          <thead>
            <tr>
              <th></th>
              <th :for={col <- @cols} class="p-2 text-left text-sm font-semibold">{col.title}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows}>
              <th class="p-2 text-left text-sm font-semibold">{row.title}</th>
              <td :for={col <- @cols} class="p-2">
                <label class="sr-only" for={"corr-#{row.id}-#{col.id}"}>
                  {row.title} → {col.title}
                </label>
                <select
                  id={"corr-#{row.id}-#{col.id}"}
                  name={"corr[#{row.id}_#{col.id}]"}
                  class="rounded border border-slate-300 px-2 py-1"
                >
                  <option
                    :for={{label, value} <- @strength_options}
                    value={value}
                    selected={value == current_strength(@strategy, row, col)}
                  >
                    {label}
                  </option>
                </select>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <button class="mt-6 rounded-lg bg-indigo-700 px-4 py-2 font-semibold text-white">Next</button>
    </form>
    """
  end

  defp render_step(%{step: "review"} = assigns) do
    ~H"""
    <div class="space-y-4">
      <p class="text-slate-600">
        You've worked through every step. Finishing will mark this strategy complete
        and show its X-Matrix.
      </p>
      <ul class="grid grid-cols-2 gap-3 text-sm">
        <li class="rounded-lg border border-slate-200 p-3">True North: {length(@true_north)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Aspirations: {length(@aspirations)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Strategies: {length(@strategies)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Evidence: {length(@evidence)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Tactics: {length(@tactics)}</li>
      </ul>
      <button
        type="button"
        phx-click="finish"
        class="rounded-lg bg-indigo-700 px-4 py-2 font-semibold text-white"
      >
        Finish
      </button>
    </div>
    """
  end

  defp render_step(assigns) do
    ~H"""
    <p class="text-slate-600">Step content for {@step}.</p>
    """
  end

  defp items_for(assigns, step) do
    case @element_steps[step] do
      :aspiration -> assigns.aspirations
      :strategy -> assigns.strategies
      :evidence -> assigns.evidence
      :tactic -> assigns.tactics
    end
  end

  defp all_elements(assigns) do
    assigns.true_north ++
      assigns.aspirations ++ assigns.strategies ++ assigns.evidence ++ assigns.tactics
  end

  defp current_strength(strategy, source, target) do
    case Enum.find(strategy.correlations, fn c ->
           c.source_element_id == source.id and c.target_element_id == target.id
         end) do
      nil -> "none"
      corr -> to_string(corr.strength)
    end
  end
end
