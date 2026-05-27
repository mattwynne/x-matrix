defmodule XMatrixWeb.InterviewLive do
  use XMatrixWeb, :live_view

  alias XMatrix.Strategies

  # The interview is a guided, conversational wizard: one thing per screen.
  # `current_step` stores the screen key (`:`-delimited) so a draft resumes
  # exactly where it was left.
  #
  # The macro order of phases. Element phases expand to an intro + a "hub"
  # screen; correlation phases expand to an intro + one screen per source item.
  @phases [
    {:single, "welcome"},
    {:single, "name"},
    {:single, "tn_statement"},
    {:single, "tn_why"},
    {:element, "aspiration"},
    {:element, "strategy"},
    {:correlation, "strategy_aspiration"},
    {:element, "evidence"},
    {:correlation, "evidence_aspiration"},
    {:element, "tactic"},
    {:correlation, "tactic_strategy"},
    {:correlation, "tactic_evidence"},
    {:single, "review"}
  ]

  # type => assign holding that type's elements
  @type_assigns %{
    "aspiration" => :aspirations,
    "strategy" => :strategies,
    "evidence" => :evidence,
    "tactic" => :tactics
  }

  # correlation key => {source assign, target assign} (source rates target)
  @correlation_pairs %{
    "strategy_aspiration" => {:strategies, :aspirations},
    "evidence_aspiration" => {:evidence, :aspirations},
    "tactic_strategy" => {:tactics, :strategies},
    "tactic_evidence" => {:tactics, :evidence}
  }

  # type => {singular label, section heading}
  @labels %{
    "aspiration" => {"aspiration", "Aspirations"},
    "strategy" => {"strategy", "Strategies"},
    "evidence" => {"piece of evidence", "Evidence"},
    "tactic" => {"tactic", "Tactics"}
  }

  @strength_options [
    {"No connection", "none"},
    {"Weak", "weak"},
    {"Medium", "medium"},
    {"Strong", "strong"}
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, load(socket, id)}
  end

  def mount(_params, _session, socket) do
    {:ok, draft} =
      Strategies.create_draft_strategy(%{title: "Untitled strategy", current_step: "welcome"})

    {:ok, push_navigate(socket, to: ~p"/interview/#{draft.id}")}
  end

  # ---- Navigation events ----

  @impl true
  def handle_event("next", _params, socket) do
    {:noreply, goto(socket, next_on_spine(socket.assigns.step, socket.assigns))}
  end

  def handle_event("back", _params, socket) do
    {:noreply, goto(socket, back_target(socket.assigns.step, socket.assigns))}
  end

  # ---- Strategy name ----

  def handle_event("save_name", %{"title" => title}, socket) do
    {:ok, strategy} =
      Strategies.update_strategy(socket.assigns.strategy, %{title: blank_to_default(title)})

    {:noreply, goto(assign(socket, :strategy, strategy), "tn_statement")}
  end

  # ---- True North (single element) ----

  def handle_event("save_tn_statement", %{"value" => value}, socket) do
    tn = List.first(socket.assigns.true_north)

    cond do
      tn && value not in [nil, ""] ->
        {:ok, _} = Strategies.update_element(tn, %{title: value})

      value not in [nil, ""] ->
        {:ok, _} =
          Strategies.add_element(socket.assigns.strategy, %{
            element_type: :true_north,
            title: value
          })

      true ->
        :noop
    end

    {:noreply, goto(load(socket, socket.assigns.strategy.id), "tn_why")}
  end

  def handle_event("save_tn_why", %{"value" => value}, socket) do
    case List.first(socket.assigns.true_north) do
      nil -> :noop
      tn -> {:ok, _} = Strategies.update_element(tn, %{description: value})
    end

    socket = load(socket, socket.assigns.strategy.id)
    {:noreply, goto(socket, next_on_spine("tn_why", socket.assigns))}
  end

  # ---- Element sections (statement then why, looping) ----

  def handle_event("add_item", %{"type" => type}, socket) do
    {:noreply, goto(socket, "elem:new:#{type}")}
  end

  def handle_event("save_statement", %{"type" => type, "value" => value}, socket) do
    if value in [nil, ""] do
      {:noreply, goto(socket, "elem:add:#{type}")}
    else
      {:ok, element} =
        Strategies.add_element(socket.assigns.strategy, %{
          element_type: String.to_existing_atom(type),
          title: value
        })

      {:noreply, goto(load(socket, socket.assigns.strategy.id), "elem:why:#{type}:#{element.id}")}
    end
  end

  def handle_event("save_why", %{"type" => type, "element_id" => id, "value" => value}, socket) do
    element = Enum.find(all_elements(socket.assigns), &(to_string(&1.id) == id))
    if element, do: Strategies.update_element(element, %{description: value})
    {:noreply, goto(load(socket, socket.assigns.strategy.id), "elem:add:#{type}")}
  end

  def handle_event("skip_why", %{"type" => type}, socket) do
    {:noreply, goto(socket, "elem:add:#{type}")}
  end

  def handle_event("delete_element", %{"id" => id}, socket) do
    element = Enum.find(all_elements(socket.assigns), &(to_string(&1.id) == id))
    if element, do: Strategies.delete_element(element)
    {:noreply, load(socket, socket.assigns.strategy.id)}
  end

  # ---- Correlations (one source per screen) ----

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

  def handle_event("finish", _params, socket) do
    {:ok, strategy} = Strategies.complete_strategy(socket.assigns.strategy)
    {:noreply, push_navigate(socket, to: ~p"/strategies/#{strategy.id}")}
  end

  # ---- Loading / assigns ----

  defp load(socket, id) do
    strategy = Strategies.get_strategy!(id)

    socket
    |> assign(:strategy, strategy)
    |> assign(:true_north, Strategies.elements_by_type(strategy, :true_north))
    |> assign(:aspirations, Strategies.elements_by_type(strategy, :aspiration))
    |> assign(:strategies, Strategies.elements_by_type(strategy, :strategy))
    |> assign(:evidence, Strategies.elements_by_type(strategy, :evidence))
    |> assign(:tactics, Strategies.elements_by_type(strategy, :tactic))
    |> then(fn s ->
      assign(s, :step, sanitize_step(strategy.current_step || "welcome", s.assigns))
    end)
  end

  defp goto(socket, step) do
    {:ok, strategy} = Strategies.set_step(socket.assigns.strategy, step)
    socket |> assign(:strategy, strategy) |> assign(:step, step)
  end

  # ---- Spine + navigation ----

  defp spine(assigns) do
    Enum.flat_map(@phases, fn
      {:single, name} ->
        [name]

      {:element, type} ->
        ["elem:intro:#{type}", "elem:add:#{type}"]

      {:correlation, key} ->
        {src_key, _} = @correlation_pairs[key]
        sources = Map.fetch!(assigns, src_key)
        ["corr:intro:#{key}" | Enum.map(sources, &"corr:src:#{key}:#{&1.id}")]
    end)
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

  # Off-spine entry screens fall back to their hub when going Back.
  defp back_target(step, assigns) do
    case String.split(step, ":") do
      ["elem", "new", type] -> "elem:add:#{type}"
      ["elem", "why", type, _id] -> "elem:add:#{type}"
      _ -> prev_on_spine(step, assigns)
    end
  end

  # Guard against a stored step that points at a now-deleted element.
  defp sanitize_step(step, assigns) do
    case String.split(step, ":") do
      ["elem", "why", type, id] ->
        if Enum.any?(all_elements(assigns), &(to_string(&1.id) == id)),
          do: step,
          else: "elem:add:#{type}"

      ["corr", "src", key, id] ->
        if Enum.any?(all_elements(assigns), &(to_string(&1.id) == id)),
          do: step,
          else: "corr:intro:#{key}"

      _ ->
        step
    end
  end

  defp all_elements(assigns) do
    assigns.true_north ++
      assigns.aspirations ++ assigns.strategies ++ assigns.evidence ++ assigns.tactics
  end

  # ---- Render ----

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :kicker, kicker(assigns.step))

    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl">
        <p class="text-sm font-semibold uppercase tracking-wide text-indigo-700">{@kicker}</p>
        <div class="mt-2">{render_step(assigns)}</div>
      </div>
    </Layouts.app>
    """
  end

  # A consistent footer used by every screen. Wrapped by a <form> on screens
  # that submit; uses a plain button on screens that only advance.
  attr :back, :boolean, default: true
  attr :primary, :string, required: true
  attr :type, :string, default: "submit"
  attr :event, :string, default: nil
  slot :secondary

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

      <div class="flex items-center gap-3">
        {render_slot(@secondary)}
        <button
          type={@type}
          phx-click={@event}
          class="rounded-lg bg-indigo-700 px-5 py-2 font-semibold text-white hover:bg-indigo-800"
        >
          {@primary}
        </button>
      </div>
    </div>
    """
  end

  defp render_step(%{step: "welcome"} = assigns) do
    ~H"""
    <h1 class="text-3xl font-bold text-slate-950">Let's build your strategy</h1>
    <div class="mt-4 space-y-3 text-slate-600">
      <p>
        We'll work through this together, one question at a time. There are no wrong
        answers — this is a thinking tool, not a form to get right.
      </p>
      <p>
        We follow Karl Scotland's X-Matrix order: your <strong>True North</strong>,
        the <strong>aspirations</strong>
        you're reaching for, the <strong>strategies</strong>
        that guide your choices, the <strong>evidence</strong>
        that shows they're working,
        and finally the <strong>tactics</strong>
        you'll try. Along the way we test how
        these connect.
      </p>
      <p>Take your time. You can leave and resume whenever you like.</p>
    </div>
    <.nav back={false} type="button" event="next" primary="Let's begin" />
    """
  end

  defp render_step(%{step: "name"} = assigns) do
    ~H"""
    <form phx-submit="save_name">
      <.question
        title="First, what should we call this strategy?"
        hint="A short working name — you can change how you think about it as we go."
      />
      <label for="title" class="sr-only">Strategy name</label>
      <.input id="title" name="title" value={default_to_blank(@strategy.title)} autofocus />
      <.nav primary="Next" />
    </form>
    """
  end

  defp render_step(%{step: "tn_statement"} = assigns) do
    assigns = assign(assigns, :tn, List.first(assigns.true_north))

    ~H"""
    <form phx-submit="save_tn_statement">
      <.question
        title="What is your True North?"
        hint="In a sentence: the direction everything should move toward. Not a target to hit, but the orienting purpose behind the work."
      />
      <label for="tn-title" class="sr-only">True North</label>
      <.input id="tn-title" name="value" value={(@tn && @tn.title) || ""} autofocus />
      <.nav primary="Next" />
    </form>
    """
  end

  defp render_step(%{step: "tn_why"} = assigns) do
    assigns = assign(assigns, :tn, List.first(assigns.true_north))

    ~H"""
    <form phx-submit="save_tn_why">
      <.question
        title="Why this direction, right now?"
        hint="What makes this the right thing to orient around? This is optional, but it's worth a moment's thought."
      />
      <label for="tn-why" class="sr-only">Why this True North</label>
      <.input
        id="tn-why"
        type="textarea"
        name="value"
        value={(@tn && @tn.description) || ""}
        rows="4"
        autofocus
      />
      <.nav primary="Next" />
    </form>
    """
  end

  defp render_step(%{step: "elem:intro:" <> type} = assigns) do
    assigns = assign(assigns, :type, type) |> assign(:copy, element_intro(type))

    ~H"""
    <h1 class="text-3xl font-bold text-slate-950">{elem_heading(@type)}</h1>
    <div class="mt-4 space-y-3 text-slate-600">
      <p :for={para <- @copy}>{para}</p>
    </div>
    <.nav type="button" event="next" primary="Continue" />
    """
  end

  defp render_step(%{step: "elem:add:" <> type} = assigns) do
    {singular, _} = @labels[type]
    items = Map.fetch!(assigns, @type_assigns[type])
    assigns = assign(assigns, type: type, singular: singular, items: items)

    ~H"""
    <h1 class="text-3xl font-bold text-slate-950">{elem_heading(@type)}</h1>

    <p :if={@items == []} class="mt-3 text-slate-500">
      Nothing here yet. Add your first {@singular} to get started.
    </p>

    <ul :if={@items != []} class="mt-4 space-y-2">
      <li
        :for={el <- @items}
        class="flex items-start justify-between gap-3 rounded-lg border border-slate-200 p-3"
      >
        <div>
          <span class="font-semibold text-slate-900">{el.title}</span>
          <span :if={el.description} class="mt-1 block text-sm text-slate-500">
            {el.description}
          </span>
        </div>
        <button
          type="button"
          phx-click="delete_element"
          phx-value-id={el.id}
          class="shrink-0 text-sm text-red-600 hover:underline"
        >
          Remove
        </button>
      </li>
    </ul>

    <button
      type="button"
      phx-click="add_item"
      phx-value-type={@type}
      class="mt-4 rounded-lg border border-indigo-300 px-4 py-2 font-medium text-indigo-700 hover:bg-indigo-50"
    >
      + Add {@singular}
    </button>

    <.nav type="button" event="next" primary="Continue" />
    """
  end

  defp render_step(%{step: "elem:new:" <> type} = assigns) do
    {singular, _} = @labels[type]
    assigns = assign(assigns, type: type, singular: singular)

    ~H"""
    <form phx-submit="save_statement">
      <input type="hidden" name="type" value={@type} />
      <.question title={statement_question(@type)} hint={statement_hint(@type)} />
      <label for="item-title" class="sr-only">New {@singular}</label>
      <.input id="item-title" name="value" value="" autofocus />
      <.nav primary="Next" />
    </form>
    """
  end

  defp render_step(%{step: "elem:why:" <> rest} = assigns) do
    [type, id] = String.split(rest, ":")
    element = Enum.find(all_elements(assigns), &(to_string(&1.id) == id))
    assigns = assign(assigns, type: type, id: id, element: element)

    ~H"""
    <form phx-submit="save_why">
      <input type="hidden" name="type" value={@type} />
      <input type="hidden" name="element_id" value={@id} />
      <.question
        title={why_question(@type)}
        hint="Optional — a sentence on what this means or why it earns its place."
      />
      <p :if={@element} class="mb-3 rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-700">
        “{@element.title}”
      </p>
      <label for="item-why" class="sr-only">Why this matters</label>
      <.input
        id="item-why"
        type="textarea"
        name="value"
        value={(@element && @element.description) || ""}
        rows="4"
        autofocus
      />
      <.nav primary="Save">
        <:secondary>
          <button
            type="button"
            phx-click="skip_why"
            phx-value-type={@type}
            class="rounded-lg px-3 py-2 font-medium text-slate-500 hover:text-slate-700"
          >
            Skip
          </button>
        </:secondary>
      </.nav>
    </form>
    """
  end

  defp render_step(%{step: "corr:intro:" <> key} = assigns) do
    assigns = assign(assigns, :copy, correlation_intro(key))

    ~H"""
    <h1 class="text-3xl font-bold text-slate-950">{corr_heading(@step)}</h1>
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
        hint="There's no need to force a connection. “No connection” is a perfectly good answer."
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
        Here's what you captured. Finishing marks the strategy complete and shows it
        as a full X-Matrix.
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

  # A shared question heading.
  attr :title, :string, required: true
  attr :hint, :string, default: nil

  defp question(assigns) do
    ~H"""
    <h1 class="text-2xl font-bold text-slate-950">{@title}</h1>
    <p :if={@hint} class="mt-2 mb-4 text-slate-500">{@hint}</p>
    """
  end

  # ---- Copy + labels ----

  defp kicker("welcome"), do: "Getting started"
  defp kicker("name"), do: "Getting started"
  defp kicker("tn_statement"), do: "True North"
  defp kicker("tn_why"), do: "True North"
  defp kicker("review"), do: "Review"

  defp kicker(step) do
    case String.split(step, ":") do
      ["elem", _, type] -> elem(@labels[type], 1)
      ["elem", _, type, _] -> elem(@labels[type], 1)
      ["corr", _, key | _] -> corr_label(key)
      _ -> ""
    end
  end

  defp elem_heading(type), do: elem(@labels[type], 1)

  defp corr_heading("corr:intro:" <> key), do: corr_label(key)
  defp corr_heading(_), do: ""

  defp corr_label("strategy_aspiration"), do: "Strategies → Aspirations"
  defp corr_label("evidence_aspiration"), do: "Evidence → Aspirations"
  defp corr_label("tactic_strategy"), do: "Tactics → Strategies"
  defp corr_label("tactic_evidence"), do: "Tactics → Evidence"

  defp tgt_singular(key) do
    {_, tgt_key} = @correlation_pairs[key]

    case tgt_key do
      :aspirations -> "aspiration"
      :strategies -> "strategy"
      :evidence -> "piece of evidence"
    end
  end

  defp statement_question("aspiration"), do: "What's one aspiration you're reaching for?"

  defp statement_question("strategy"),
    do: "What's one strategy — ideally an “even over” statement?"

  defp statement_question("evidence"), do: "What's one piece of evidence you'll watch?"
  defp statement_question("tactic"), do: "What's one tactic you'll try?"

  defp statement_hint("aspiration"),
    do: "An ambitious outcome — the change you want to see, not the work to get there."

  defp statement_hint("strategy"),
    do:
      "Karl Scotland suggests phrasing strategies as “even over” statements — like the Agile Manifesto. Name two good things and say which you'll favour when they conflict, e.g. “long-term prevention even over short-term relief”. That forces a real choice rather than a platitude."

  defp statement_hint("evidence"),
    do:
      "A leading indicator you'd expect to move if things are working — something to see more or less of."

  defp statement_hint("tactic"),
    do: "A concrete action or experiment — a bet that should generate the evidence you defined."

  defp why_question("aspiration"), do: "Why does this aspiration matter?"
  defp why_question("strategy"), do: "Why this strategy — what does it focus you on, or rule out?"
  defp why_question("evidence"), do: "Why this indicator — what would a change in it tell you?"
  defp why_question("tactic"), do: "Why this tactic — what evidence do you expect it to generate?"

  defp element_intro("aspiration"),
    do: [
      "Aspirations are the ambitious outcomes you're reaching for — challenges rather than safe, predictable targets.",
      "Think about the change you want to see in the world, not the work you'll do to get there. We'll add the work later."
    ]

  defp element_intro("strategy"),
    do: [
      "Strategies are the guiding policies that shape your choices — the “how” at a high level. They're enabling constraints: they focus attention and deliberately rule some options out.",
      "Karl Scotland recommends writing them as “even over” statements, in the spirit of the Agile Manifesto: “X even over Y”. Both X and Y are good, but you're declaring which you'll prioritise when they pull against each other — for example, “long-term prevention even over short-term relief”.",
      "This makes a strategy a genuine decision rather than a platitude no one could argue with."
    ]

  defp element_intro("evidence"),
    do: [
      "Evidence is the leading indicators that tell you whether your strategies are working — things you'd expect to see more or less of.",
      "We define this before tactics on purpose, so you're agreeing how you'll know it's working — not just justifying work you'd already planned."
    ]

  defp element_intro("tactic"),
    do: [
      "Tactics are the concrete actions and experiments you'll try.",
      "Treat them as hypotheses: bets that should generate the evidence you just defined."
    ]

  defp correlation_intro("strategy_aspiration"),
    do: [
      "Now let's test how things connect. For each strategy, how strongly does it contribute to each aspiration?",
      "A strategy that supports nothing — or an aspiration that nothing supports — is worth a second look."
    ]

  defp correlation_intro("evidence_aspiration"),
    do: [
      "For each piece of evidence, how strongly does it indicate progress toward each aspiration?",
      "This checks that your indicators actually track the outcomes you care about."
    ]

  defp correlation_intro("tactic_strategy"),
    do: [
      "For each tactic, how strongly does it enact each strategy?",
      "Tactics that align with no strategy may be busywork; strategies with no tactics have no way to happen."
    ]

  defp correlation_intro("tactic_evidence"),
    do: [
      "Finally, for each tactic, how strongly should it move each piece of evidence?",
      "This is the feedback loop: tactics generate evidence, evidence shows whether strategies are working."
    ]

  defp current_strength(_strategy, nil, _target), do: "none"

  defp current_strength(strategy, source, target) do
    case Enum.find(strategy.correlations, fn c ->
           c.source_element_id == source.id and c.target_element_id == target.id
         end) do
      nil -> "none"
      corr -> to_string(corr.strength)
    end
  end

  defp blank_to_default(title) when title in [nil, ""], do: "Untitled strategy"
  defp blank_to_default(title), do: title

  defp default_to_blank("Untitled strategy"), do: ""
  defp default_to_blank(title), do: title || ""
end
