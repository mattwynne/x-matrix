defmodule XMatrixWeb.XMatrixLive do
  use XMatrixWeb, :live_view

  alias XMatrix.Strategies

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    strategy = Strategies.get_strategy!(id)

    {:ok,
     socket
     |> assign(:strategy, strategy)
     |> assign(:true_north, Strategies.elements_by_type(strategy, :true_north))
     |> assign(:aspirations, Strategies.elements_by_type(strategy, :aspiration))
     |> assign(:strategies, Strategies.elements_by_type(strategy, :strategy))
     |> assign(:evidence, Strategies.elements_by_type(strategy, :evidence))
     |> assign(:tactics, Strategies.elements_by_type(strategy, :tactic))}
  end

  def strength_mark(:strong), do: "◎"
  def strength_mark(:medium), do: "○"
  def strength_mark(:weak), do: "△"
  def strength_mark(_), do: ""

  def strength_label(:strong), do: "strong"
  def strength_label(:medium), do: "medium"
  def strength_label(:weak), do: "weak"
  def strength_label(_), do: "none"

  def element_label(:true_north), do: "True North"
  def element_label(:aspiration), do: "Aspiration"
  def element_label(:strategy), do: "Strategy"
  def element_label(:evidence), do: "Evidence"
  def element_label(:tactic), do: "Tactic"

  defp correlation_for(correlations, source, target) do
    Enum.find(correlations, fn correlation ->
      correlation.source_element_id == source.id and correlation.target_element_id == target.id
    end)
  end

  attr :true_north, :list, required: true
  attr :strategies, :list, required: true
  attr :tactics, :list, required: true
  attr :evidence, :list, required: true
  attr :aspirations, :list, required: true
  attr :correlations, :list, required: true

  def x_matrix(assigns) do
    ns = length(assigns.strategies)
    ne = length(assigns.evidence)
    nt = length(assigns.tactics)
    na = length(assigns.aspirations)

    center_col = ns + 1
    center_row = nt + 1

    istrategies = Enum.with_index(assigns.strategies, 1)
    ievidence = Enum.with_index(assigns.evidence, 1)
    itactics = Enum.with_index(assigns.tactics, 1)
    iaspirations = Enum.with_index(assigns.aspirations, 1)

    corrs = assigns.correlations

    top_left =
      for {tactic, r} <- itactics,
          {strategy, c} <- istrategies,
          do: %{row: r, col: c, correlation: correlation_for(corrs, tactic, strategy)}

    top_right =
      for {tactic, r} <- itactics,
          {evidence, j} <- ievidence,
          do: %{row: r, col: ns + 1 + j, correlation: correlation_for(corrs, tactic, evidence)}

    bottom_left =
      for {aspiration, k} <- iaspirations,
          {strategy, c} <- istrategies,
          do: %{
            row: nt + 1 + k,
            col: c,
            correlation: correlation_for(corrs, strategy, aspiration)
          }

    bottom_right =
      for {aspiration, k} <- iaspirations,
          {evidence, j} <- ievidence,
          do: %{
            row: nt + 1 + k,
            col: ns + 1 + j,
            correlation: correlation_for(corrs, evidence, aspiration)
          }

    assigns =
      assigns
      |> assign(:center_col, center_col)
      |> assign(:center_row, center_row)
      |> assign(
        :grid_style,
        "grid-template-columns: repeat(#{ns}, 3.25rem) minmax(18rem, 28rem) repeat(#{ne}, 3.25rem); " <>
          "grid-template-rows: repeat(#{nt}, 3.25rem) minmax(12rem, 1fr) repeat(#{na}, 3.25rem);"
      )
      |> assign(:istrategies, istrategies)
      |> assign(:ievidence, ievidence)
      |> assign(:itactics, itactics)
      |> assign(:iaspirations, iaspirations)
      |> assign(:evidence_offset, ns + 1)
      |> assign(:aspiration_offset, nt + 1)
      |> assign(:cells, top_left ++ top_right ++ bottom_left ++ bottom_right)

    ~H"""
    <div class="overflow-x-auto pb-2" aria-label="Karl Scotland style X-Matrix">
      <div
        class="mx-auto grid min-w-[68rem] rounded-2xl border-2 border-slate-800 bg-white [&>*]:border [&>*]:border-slate-200"
        style={@grid_style}
      >
        <%!-- Correlation marks (all four quadrants) --%>
        <div
          :for={cell <- @cells}
          class="flex items-center justify-center text-2xl text-slate-900"
          style={"grid-column: #{cell.col}; grid-row: #{cell.row};"}
          title={cell.correlation && cell.correlation.rationale}
        >
          <span :if={cell.correlation && cell.correlation.strength != :none}>
            {strength_mark(cell.correlation.strength)}
            <span class="sr-only">{strength_label(cell.correlation.strength)}</span>
          </span>
        </div>

        <%!-- Strategy names: vertical, in the centre row --%>
        <div
          :for={{strategy, c} <- @istrategies}
          class="flex items-center justify-center p-1 text-center text-[11px] font-medium leading-tight text-slate-800 [writing-mode:vertical-rl] rotate-180"
          style={"grid-column: #{c}; grid-row: #{@center_row};"}
        >
          <span>{strategy.title}</span>
        </div>

        <%!-- Evidence names: vertical, in the centre row --%>
        <div
          :for={{evidence, j} <- @ievidence}
          class="flex items-center justify-center p-1 text-center text-[11px] font-medium leading-tight text-slate-800 [writing-mode:vertical-rl] rotate-180"
          style={"grid-column: #{@evidence_offset + j}; grid-row: #{@center_row};"}
        >
          <span>{evidence.title}</span>
        </div>

        <%!-- Tactic names: horizontal, in the centre column --%>
        <div
          :for={{tactic, r} <- @itactics}
          class="flex items-center justify-center p-2 text-center text-sm font-medium text-slate-800"
          style={"grid-column: #{@center_col}; grid-row: #{r};"}
        >
          <span>{tactic.title}</span>
        </div>

        <%!-- Aspiration names: horizontal, in the centre column --%>
        <div
          :for={{aspiration, k} <- @iaspirations}
          class="flex items-center justify-center p-2 text-center text-sm font-medium text-slate-800"
          style={"grid-column: #{@center_col}; grid-row: #{@aspiration_offset + k};"}
        >
          <span>{aspiration.title}</span>
        </div>

        <%!-- True North + axis labels, centre cell --%>
        <div
          class="relative flex items-center justify-center p-10"
          style={"grid-column: #{@center_col}; grid-row: #{@center_row};"}
        >
          <span class="absolute left-1/2 top-1.5 -translate-x-1/2 text-xs font-extrabold uppercase tracking-[0.2em] text-slate-500">
            Tactics
          </span>
          <span class="absolute bottom-1.5 left-1/2 -translate-x-1/2 text-xs font-extrabold uppercase tracking-[0.2em] text-slate-500">
            Aspirations
          </span>
          <span class="absolute left-1.5 top-1/2 -translate-y-1/2 text-xs font-extrabold uppercase tracking-[0.2em] text-slate-500 [writing-mode:vertical-rl] rotate-180">
            Strategies
          </span>
          <span class="absolute right-1.5 top-1/2 -translate-y-1/2 text-xs font-extrabold uppercase tracking-[0.2em] text-slate-500 [writing-mode:vertical-rl]">
            Evidence
          </span>

          <div class="rounded-2xl bg-indigo-700 px-6 py-8 text-center text-white shadow-inner">
            <h2 class="text-xl font-black uppercase tracking-wide">True North</h2>
            <ul class="mt-3 space-y-2">
              <li :for={element <- @true_north}>
                <span class="block text-base font-bold">{element.title}</span>
                <span class="mt-1 block text-xs text-indigo-100">{element.description}</span>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
