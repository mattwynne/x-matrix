# Faithful X-Matrix Layout

Date: 2026-05-27
Status: draft

## Goal

Re-render the read-only X-Matrix at `/` so it reads as a single connected
matrix in the style of Karl Scotland's X-Matrix, rather than the current set of
separate floating cards. The structure — not just the vocabulary — should be
recognisable as an X-Matrix: four axes around a central True North, with
correlation marks at the genuine intersections of two axes.

This is a **view-layer change only**. The domain model, context functions,
migration, and seeds already support everything needed.

## Background / Context

Iteration 001 deliberately left the visualisation "rough" (pixel-perfect was
out of scope) and produced a dashboard of rounded cards: True North in the
centre, four axis cards, and four separate correlation-table cards. It captured
the X-Matrix *vocabulary* but not its defining *visual grammar* — a single
contiguous grid where each correlation mark sits at the literal crossing of an
item from one axis and an item from an adjacent axis.

The seeded data maps cleanly onto the classic layout:

- **Strategies** — left columns
- **Tactics** — top rows
- **Evidence** — right columns
- **Aspirations** — bottom rows
- **True North** — centre

All four correlation pairs in the seed populate the four corner quadrants:

| Quadrant     | Rows        | Columns    | Seeded pair         |
|--------------|-------------|------------|---------------------|
| Top-left     | Tactics     | Strategies | Tactic → Strategy   |
| Top-right    | Tactics     | Evidence   | Tactic → Evidence   |
| Bottom-left  | Aspirations | Strategies | Strategy → Aspiration |
| Bottom-right | Aspirations | Evidence   | Evidence → Aspiration |

## Design

### Single connected grid

Render the matrix as one CSS grid (not nine cards). The grid geometry:

- **Columns:** `[Strategy item columns…] [centre column] [Evidence item columns…]`
- **Rows:** `[Tactic item rows…] [centre row] [Aspiration item rows…]`

With this geometry the four correlation quadrants fall out automatically at the
true axis intersections, and the centre cell holds True North. Concretely, with
the seeded data the grid is 5 columns (2 strategies + centre + 2 evidence) by
6 rows (3 tactics + centre + 2 aspirations), but the implementation must derive
the column and row counts from the actual element lists, not hard-code them.

### Self-labelling rows and columns (no numbering)

Each axis item is written *in its own track*, so marks are identified by
position alone — no numeric index headers:

- **Strategy** and **Evidence** items: vertical text (`writing-mode:
  vertical-rl`) written into their own column, within the centre row band. A
  strategy's column runs continuously from its top-left quadrant marks (tactic
  rows) down through its name to its bottom-left quadrant marks (aspiration
  rows).
- **Tactic** and **Aspiration** items: horizontal text written into their own
  row, within the centre column band. A tactic's row runs from its top-left
  quadrant marks (strategy columns) across its name to its top-right quadrant
  marks (evidence columns).

Every correlation mark therefore sits at the crossing of a named row and a named
column and can be traced visually, exactly as in the reference image.

### Axis labels

The four axis labels (STRATEGIES, TACTICS, EVIDENCE, ASPIRATIONS) sit at the
edges of the central True North box: Tactics top, Aspirations bottom, Strategies
left (vertical), Evidence right (vertical). They must have clear contrast and
enough breathing room not to crowd or overlap the vertical item names — give
them their own spacing/margin rather than overlapping the item tracks.

### True North

The centre cell holds the True North element(s): the indigo box kept from the
current app (a "blend" of faithful structure with the app's palette), with the
title prominent and the description beneath. It spans the single centre row ×
centre column cell where the axes cross.

### Strength encoding — Hoshin Kanri symbols

Monochrome symbols, no colour:

- ◎ strong
- ○ medium
- △ weak
- blank cell = no connection (`:none` or absent correlation)

A legend below the matrix shows the three symbols. Each mark carries:

- the correlation's `rationale` as a `title` (hover tooltip), and
- an `sr-only` text label of the strength for screen readers,

so meaning never depends on the glyph shape alone.

### Visual style ("faithful blend")

Faithful classic skeleton with restrained modern touches:

- Thin, uniform grid lines; monochrome marks; neutral palette.
- A rounded outer frame around the whole matrix.
- The indigo True North box at the centre.
- Clean Tailwind typography consistent with the rest of the app.
- No coloured strength dots, no tinted quadrants.

### Responsiveness

The matrix cannot reflow without breaking its grammar. It keeps its structure at
all widths: wrap it in a horizontally scrollable container (`overflow-x-auto`)
with a sensible `min-width`, so on narrow screens the user scrolls rather than
seeing a collapsed/stacked layout.

## Components

Refactor the rendering in `lib/x_matrix_web/live/x_matrix_live.ex` and
`lib/x_matrix_web/live/x_matrix_live.html.heex`:

- Replace the `axis` and `correlation_grid` components and the card-based
  template with a single matrix component (or a small set of focused helpers)
  that places items and marks into the one CSS grid by computed
  `grid-row` / `grid-column`.
- Keep the existing helper functions where still useful:
  - `correlation_for/3` — look up a correlation for a (source, target) pair.
  - `strength_mark/1` — repurpose to return the Hoshin glyph (◎ / ○ / △) and an
    empty/blank for `:none`/`nil`.
  - `strength_classes/1` — likely no longer needed once colour is dropped;
    remove if unused (no dead code).
- The LiveView `mount/3` already assigns `true_north`, `aspirations`,
  `strategies`, `evidence`, `tactics`, and `strategy.correlations`. No new
  assigns are required, but a small derived structure (e.g. a quadrant lookup)
  may be computed in the template/component for clarity.

A correlation mark is rendered for a quadrant cell `(row_item, col_item)` by
finding the correlation whose `source_element`/`target_element` matches that
pair in either direction relevant to the quadrant. The lookup must match the
direction the seed stores each pair (see the table above): e.g. top-left uses
tactic-as-source, strategy-as-target.

## Testing

Extend the existing `phoenix_test` test for `/` so it still verifies:

- the seeded strategy title renders;
- at least one element of each of the five types renders (True North,
  Aspiration, Strategy, Evidence, Tactic) by title;
- at least two distinct strength levels are present (e.g. a strong and a medium
  mark, asserted via their `sr-only` strength text so the assertion does not
  depend on the glyph);
- the page remains read-only (no forms / edit controls).

Update any assertions that depended on the old card markup or `→`-style
correlation headings.

## Out of scope

- Schema, context, migration, or seed changes.
- Editing, creating, deleting, or rearranging elements.
- Numeric axis indices / numbered headers (explicitly dropped — rows and columns
  are self-labelling).
- A separate stacked mobile layout (horizontal scroll is the chosen fallback).
- Multiple strategies / workspace switching.

## Acceptance Criteria

- Visiting `/` returns HTTP 200 and shows the seeded strategy by title.
- The visualisation is a single connected grid: Strategies (left columns),
  Tactics (top rows), Evidence (right columns), Aspirations (bottom rows), True
  North in the centre.
- Correlation marks appear at the intersection of the correct row item and
  column item, in all four quadrants that the seed populates.
- Strength is shown with Hoshin symbols (◎ strong / ○ medium / △ weak), with at
  least two distinct levels visually present, and a legend.
- Each mark exposes its rationale on hover and a screen-reader strength label.
- Axis labels are legible and do not overlap item names.
- The matrix stays intact and horizontally scrolls on narrow screens.
- The page is read-only.
- `dev check` passes (formatting, zero-warning compile, tests), and the
  `phoenix_test` for `/` passes.

## Risks / Follow-ups

- Long item titles in narrow vertical columns may wrap awkwardly; tune column
  widths and line height during implementation. If a title is unworkable in a
  vertical track, fall back to the rendered result staying legible (the marks
  remaining traceable to a named track is the hard requirement).
- Once editing/interview flows arrive, this single-strategy view will need to
  generalise; the grid component should keep item/correlation lookup logic
  separate from layout so it can be reused.
