# Faithful X-Matrix Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-render the read-only X-Matrix at `/` as a single connected CSS grid (Strategies left, Tactics top, Evidence right, Aspirations bottom, True North centre) with Hoshin-symbol correlation marks at the true axis intersections.

**Architecture:** View-layer only. Replace the card-based `axis`/`correlation_grid` components and template in the LiveView with one `x_matrix/1` function component that places every item-name track, correlation mark, and the True North box into a single CSS grid via explicit `grid-column`/`grid-row` inline styles. No schema, context, migration, or seed changes.

**Tech Stack:** Elixir, Phoenix LiveView (HEEx), Tailwind CSS, `phoenix_test`.

**Spec:** `docs/superpowers/specs/2026-05-27-faithful-x-matrix-layout-design.md`

---

## Background the implementer needs

The page is a Phoenix LiveView. `mount/3` in `lib/x_matrix_web/live/x_matrix_live.ex`
already assigns these (do not change it):

- `@strategy` — has `.title`, `.description`, and `.correlations` (a preloaded list).
- `@true_north`, `@aspirations`, `@strategies`, `@evidence`, `@tactics` — lists of
  `StrategyElement` structs, each with `.title` and `.description`.

A `StrategyCorrelation` has `.source_element_id`, `.target_element_id`, `.strength`
(`:strong | :medium | :weak | :none`), and `.rationale`. The existing helper
`correlation_for/3` looks one up by `(source, target)` using element IDs — no
association preloading is required.

**Quadrant ↔ correlation direction** (the seed stores each pair in this direction —
get this right or marks land in the wrong corner / go missing):

| Quadrant      | Row items   | Column items | Lookup `correlation_for(corrs, …, …)` |
|---------------|-------------|--------------|----------------------------------------|
| Top-left      | Tactics     | Strategies   | `(tactic, strategy)`                   |
| Top-right     | Tactics     | Evidence     | `(tactic, evidence)`                   |
| Bottom-left   | Aspirations | Strategies   | `(strategy, aspiration)`               |
| Bottom-right  | Aspirations | Evidence     | `(evidence, aspiration)`               |

**Grid coordinates** (1-based, `ns/ne/nt/na` = counts of strategies/evidence/tactics/aspirations):

- Strategy column `c` (1..ns) → `grid-column: c`
- Centre column → `ns + 1`
- Evidence column `j` (1..ne) → `grid-column: ns + 1 + j`
- Tactic row `r` (1..nt) → `grid-row: r`
- Centre row → `nt + 1`
- Aspiration row `k` (1..na) → `grid-row: nt + 1 + k`

Run the full check with: `./dev check` (it runs `MIX_ENV=test mix check`). Run a
single test file with: `mix test test/x_matrix_web/live/x_matrix_live_test.exs`.

---

## File structure

- **Modify** `lib/x_matrix_web/live/x_matrix_live.ex` — remove `axis/1`,
  `correlation_grid/1`, and `strength_classes/1`; change `strength_mark/1` to
  Hoshin glyphs; add `strength_label/1` and the new `x_matrix/1` component.
- **Modify** `lib/x_matrix_web/live/x_matrix_live.html.heex` — replace the
  card grid with a call to `<.x_matrix .../>` plus the legend.
- **Modify** `test/x_matrix_web/live/x_matrix_live_test.exs` — update assertions
  to the new markup (drop the old `li`/`→` expectations).

---

## Task 1: Update the test to expect the new matrix markup

**Files:**
- Test: `test/x_matrix_web/live/x_matrix_live_test.exs:64-82`

The `setup` block (lines 1-62) stays exactly as-is. It seeds one element of each
type and two correlations: `strategy → aspiration` (`:strong`) and
`tactic → evidence` (`:weak`). Under the quadrant table those render in the
bottom-left and top-right quadrants respectively, so both strengths will appear.

- [ ] **Step 1: Replace the test body (lines 64-82) with the new assertions**

```elixir
  test "renders the seeded read-only X-Matrix", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", text: "Multi-agency homelessness reduction strategy")
    |> assert_has("h2", text: "True North")
    |> assert_has("span", text: "Strategies")
    |> assert_has("span", text: "Tactics")
    |> assert_has("span", text: "Evidence")
    |> assert_has("span", text: "Aspirations")
    |> assert_has("span", text: "Everyone has a safe, stable place to call home")
    |> assert_has("span", text: "Reduce rough sleeping by 50%")
    |> assert_has("span", text: "Intervene before crisis")
    |> assert_has("span", text: "Median days from referral to stable housing")
    |> assert_has("span", text: "Shared by-name case conference")
    |> assert_has("span.sr-only", text: "strong")
    |> assert_has("span.sr-only", text: "weak")
    |> refute_has("form")
    |> refute_has("button", text: "Edit")
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mix test test/x_matrix_web/live/x_matrix_live_test.exs`
Expected: FAIL — the current template renders axis labels in `h2` and items in
`li`, so the new `span` assertions (and `span.sr-only` strength text) will not match.

- [ ] **Step 3: Commit the failing test**

```bash
git add test/x_matrix_web/live/x_matrix_live_test.exs
git commit -m "test: expect connected X-Matrix grid markup"
```

---

## Task 2: Rewrite helpers and add the matrix component

**Files:**
- Modify: `lib/x_matrix_web/live/x_matrix_live.ex`

- [ ] **Step 1: Replace the strength helpers**

Replace the existing `strength_classes/*` and `strength_mark/*` definitions
(lines 20-29) with Hoshin glyphs plus a screen-reader label. Delete
`strength_classes` entirely — it is no longer referenced.

```elixir
  def strength_mark(:strong), do: "◎"
  def strength_mark(:medium), do: "○"
  def strength_mark(:weak), do: "△"
  def strength_mark(_), do: ""

  def strength_label(:strong), do: "strong"
  def strength_label(:medium), do: "medium"
  def strength_label(:weak), do: "weak"
  def strength_label(_), do: "none"
```

- [ ] **Step 2: Delete the old `axis/1` and `correlation_grid/1` components**

Remove the `correlation_grid/1` component and its `attr` declarations (lines
43-99) and the `axis/1` component and its `attr` declarations (lines 101-130).
Keep `correlation_for/3` and `element_label/1`.

- [ ] **Step 3: Add the `x_matrix/1` component**

Add this component to the module (after `correlation_for/3`):

```elixir
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
      for {tactic, r} <- itactics, {strategy, c} <- istrategies,
          do: %{row: r, col: c, correlation: correlation_for(corrs, tactic, strategy)}

    top_right =
      for {tactic, r} <- itactics, {evidence, j} <- ievidence,
          do: %{row: r, col: ns + 1 + j, correlation: correlation_for(corrs, tactic, evidence)}

    bottom_left =
      for {aspiration, k} <- iaspirations, {strategy, c} <- istrategies,
          do: %{row: nt + 1 + k, col: c, correlation: correlation_for(corrs, strategy, aspiration)}

    bottom_right =
      for {aspiration, k} <- iaspirations, {evidence, j} <- ievidence,
          do: %{row: nt + 1 + k, col: ns + 1 + j, correlation: correlation_for(corrs, evidence, aspiration)}

    assigns =
      assigns
      |> assign(:center_col, center_col)
      |> assign(:center_row, center_row)
      |> assign(:grid_style,
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
```

- [ ] **Step 4: Compile to check for syntax/warnings**

Run: `mix compile --warnings-as-errors`
Expected: compiles with no warnings. (The template still uses the old components
until Task 3, but the module itself must compile cleanly.)

- [ ] **Step 5: Commit**

```bash
git add lib/x_matrix_web/live/x_matrix_live.ex
git commit -m "feat: add connected X-Matrix grid component"
```

---

## Task 3: Wire the component into the template and add the legend

**Files:**
- Modify: `lib/x_matrix_web/live/x_matrix_live.html.heex`

- [ ] **Step 1: Replace the `<section>` matrix block and legend (lines 11-125) with the component call + Hoshin legend**

Keep the `<Layouts.app>` wrapper (line 1), the `<main>` open tag (line 2), and the
`<header>` (lines 3-9). Replace everything from the opening
`<section aria-label="Karl Scotland style X-Matrix visualization">` through the
end of the legend `</section>` with:

```heex
    <.x_matrix
      true_north={@true_north}
      strategies={@strategies}
      tactics={@tactics}
      evidence={@evidence}
      aspirations={@aspirations}
      correlations={@strategy.correlations}
    />

    <section class="mt-6 rounded-2xl border border-slate-200 bg-white p-4 text-sm text-slate-600 shadow-sm">
      <h2 class="font-bold text-slate-900">Correlation strength legend</h2>
      <div class="mt-3 flex flex-wrap gap-6">
        <span class="flex items-center gap-2">
          <span class="text-2xl text-slate-900">◎</span> strong
        </span>
        <span class="flex items-center gap-2">
          <span class="text-2xl text-slate-900">○</span> medium
        </span>
        <span class="flex items-center gap-2">
          <span class="text-2xl text-slate-900">△</span> weak
        </span>
        <span class="text-slate-400">Hover a mark to see its rationale.</span>
      </div>
    </section>
```

The file should now end with the `</main>` and `</Layouts.app>` closing tags that
were already there (lines 126-127).

- [ ] **Step 2: Run the test from Task 1 to verify it passes**

Run: `mix test test/x_matrix_web/live/x_matrix_live_test.exs`
Expected: PASS (1 test, 0 failures).

- [ ] **Step 3: Commit**

```bash
git add lib/x_matrix_web/live/x_matrix_live.html.heex
git commit -m "feat: render X-Matrix via connected grid component"
```

---

## Task 4: Full check and manual visual verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full project check**

Run: `./dev check`
Expected: PASS — formatting clean, zero-warning compile, all tests green. If
formatting fails, run `mix format` and re-run; commit any formatting changes with
`git commit -am "style: mix format"`.

- [ ] **Step 2: Reseed and view the running app**

Ensure the dev DB is seeded (`mix ecto.reset` if needed), start the server
(`mix phx.server`), and open `http://localhost:4000`. Confirm against the spec's
acceptance criteria:

- One connected grid (no floating cards): Strategies down the left columns,
  Tactics across the top rows, Evidence down the right columns, Aspirations across
  the bottom rows, True North in the centre.
- Marks sit at the correct intersections — e.g. bottom-left "Intervene before
  crisis" × "Prevent avoidable family homelessness" is ◎ (strong); top-left
  "Coordinate around the person" × "Shared by-name case conference" is ◎.
- Hoshin glyphs ◎/○/△ render, with at least two distinct strengths visible, and a
  legend below.
- Axis labels (Strategies/Tactics/Evidence/Aspirations) are legible and not
  overlapping the vertical item names.
- Narrow window → the matrix scrolls horizontally rather than collapsing.
- No forms or edit controls.

- [ ] **Step 3: (If anything looks off) tune widths/spacing and re-verify**

Adjust only Tailwind classes in the component: the `min-w-[68rem]` on the grid,
the `3.25rem` track sizes and `minmax(...)` centre sizes in `@grid_style`, or the
axis-label offsets (`top-1.5`, `left-1.5`, etc.). Re-run `./dev check` and
re-check the page after any change. Commit with
`git commit -am "style: tune X-Matrix grid spacing"`.
```
