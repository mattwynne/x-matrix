# Structured Interview Without LLM

Date: 2026-05-27
Status: proposed

## Goal

Add a guided, linear interview that walks a user through Karl Scotland's
X-Matrix facilitation order to build **one new strategy from scratch**. Each
step is persisted as the user completes it, an in-progress interview can be
resumed, and finishing the interview lands the user on the read-only X-Matrix
for the strategy they just created.

## Background / Context

Iteration 001 produced a read-only, seeded X-Matrix backed by a real persisted
domain model (a `strategies` root, a generic `strategy_elements` table with a
type field, and a `strategy_correlations` table with a strength). This iteration
adds the first authoring capability — but deliberately *without* any LLM, to
prove the workflow before adding extraction.

The distinctive value of the interview is that it enforces Scotland's
facilitation order, in particular defining **Evidence before Tactics** to avoid
confirmation bias and jumping to pre-existing work. From the research notes, the
practical order is:

1. True North
2. Aspirations
3. Strategies
4. Correlations: Strategies → Aspirations
5. Evidence
6. Correlations: Evidence → Aspirations
7. Tactics
8. Correlations: Tactics → Strategies
9. Correlations: Tactics → Evidence

The existing generic element + correlation schema already supports everything
the interview needs to store; the only schema additions are draft/resume
bookkeeping on the `strategies` row.

This iteration does **not** include the separate "faithful X-Matrix layout"
view rework (tracked in its own spec); the matrix continues to render with the
current view, now parameterised by strategy id.

## Scope

### In scope

- A landing page at `/` offering: view the example (seeded) matrix, start a new
  interview, and resume an in-progress draft when one exists.
- A linear interview wizard, one step per screen, following the 9-step
  facilitation order above, plus a final review/finish step.
- Incremental persistence: the strategy row is created at the first step, and
  each subsequent step writes its elements/correlations to the database before
  advancing.
- Resume: an unfinished draft reopens at the step it was left on, with all
  previously entered data intact.
- Element steps (True North, Aspirations, Strategies, Evidence, Tactics) let the
  user add, edit, and remove items (True North is a single element).
- Correlation steps render a grid of the relevant rows × columns; each cell is a
  dropdown selecting `none / weak / medium / strong` (default `none`). Saved on
  Next.
- Correlation direction stored to match the seed and the faithful-layout spec:
  - Step 4: source = strategy, target = aspiration
  - Step 6: source = evidence, target = aspiration
  - Step 8: source = tactic, target = strategy
  - Step 9: source = tactic, target = evidence
- The read-only matrix is reachable at `/strategies/:id`; finishing the
  interview navigates there for the new strategy.
- Write-side context functions in `XMatrix.Strategies`.
- `phoenix_test` coverage for the landing page, a full interview walk-through,
  order enforcement, resume, and incremental persistence.

### Out of scope

- LLM integration / extraction (iteration 003).
- Coherence checks and LLM-suggested correlations (iteration 004).
- Tracking / review loop, tactic status, observations (iteration 005).
- Authentication or user accounts.
- A full multi-strategy management UI beyond the single "resume draft" link and
  per-id matrix route (no list/index, rename, delete, archive).
- Editing a strategy after it has been marked complete.
- Free / non-linear step navigation (the order is intentionally enforced).
- The faithful X-Matrix layout view rework (separate spec).
- Click-to-cycle symbol or radio correlation inputs (dropdown chosen).

## Acceptance Criteria

- Visiting `/` returns HTTP 200 and shows three choices: view the example
  matrix, start an interview, and (only when a draft exists) resume.
- "View example matrix" reaches the seeded strategy's read-only matrix at
  `/strategies/:id`.
- Starting an interview creates a `:draft` strategy and opens step 1.
- The wizard presents the 9 steps in the facilitation order; the user cannot
  reach a later step (e.g. Tactics) before completing the earlier ones (e.g.
  Evidence).
- Element steps allow adding multiple items (True North limited to one) with
  title and optional description, and removing items before advancing.
- Each correlation step shows a grid of the correct rows × columns with a
  per-cell strength dropdown defaulting to `none`; selections persist on Next.
- Stored correlations use the source/target direction listed in scope.
- Data entered on a step survives a full page reload taken mid-interview
  (incremental persistence).
- An unfinished draft can be resumed from `/` and reopens at its saved step with
  prior data present.
- Finishing marks the strategy `:complete` and navigates to its matrix at
  `/strategies/:id`, which displays the entered elements of each type and at
  least one correlation with a visible strength.
- The completed-strategy matrix is read-only (no forms or mutation controls).
- `dev check` passes (formatting, zero-warning compile, tests), including new
  `phoenix_test` coverage.

## Open Business Decisions

None known. (The strategy name is captured together with True North on step 1.)

## Implementation Plan

1. **Migration** — `mix ecto.gen.migration add_strategy_interview_state`:
   add `status` (`Ecto.Enum [:draft, :complete]`, default `:draft`) and
   `current_step` (string) to `strategies`. Backfill existing/seeded rows to
   `:complete`.
2. **Schema** — add `status` and `current_step` to
   `XMatrix.Strategies.Strategy` and its changeset; keep element/correlation
   schemas unchanged.
3. **Context write functions** in `XMatrix.Strategies`:
   - `create_draft_strategy/1`
   - `get_strategy!/1` (generalise `get_seeded_strategy!` to load any id with
     elements + correlations preloaded; keep a seeded helper or look up the
     oldest for the example link)
   - `get_resumable_draft/0`
   - `add_element/2`, `update_element/2`, `delete_element/1`
   - `upsert_correlation/4` (set or clear a (source, target) pair's strength)
   - `set_step/2`, `complete_strategy/1`
4. **Matrix route** — rename/generalise `XMatrixLive` to load by id at
   `/strategies/:id`; update the existing test to use the seeded strategy's id.
5. **Landing** — `/` becomes a landing LiveView (or controller) with links to
   the example matrix, a new interview, and the resumable draft when present.
6. **Interview LiveView** — `XMatrixWeb.InterviewLive` at `/interview` (start →
   redirect to draft id) and `/interview/:id`. A `current_step` assign drives
   which sub-template renders. Two focused render helpers: one for
   element-collection steps, one for correlation-grid steps. Back/Next advance
   and persist; Next on the final review step completes and navigates to the
   matrix.
7. **Forms** — use `to_form/2` + `<.input>` for element entry; correlation grid
   cells are `<.input type="select">` per pair with explicit DOM ids.
8. **Tests** (`phoenix_test`, TDD): landing choices and example link; full
   walk-through to completion; order enforcement; resume at saved step;
   reload-mid-step persistence; completed matrix is read-only.
9. Run and fix `dev check` until green.

## Open Technical Decisions

- `current_step` representation: a string slug per step (e.g. `"true_north"`,
  `"strategy_aspiration"`) versus an integer index. Prefer named slugs for
  readability and resilience to reordering.
- Whether the landing page is a LiveView or a plain controller — either is fine;
  pick the simpler given no dynamic state is needed beyond the draft lookup.
- Element-step interaction detail (inline list with add/remove via LiveView
  events vs. a repeating inputs form) — resolve during TDD; the acceptance
  criterion is add/edit/remove before advancing.
- How aggressively to validate (e.g. require at least one Aspiration before
  leaving step 2). Default: require True North and a strategy name; allow other
  element steps to proceed but surface a gentle hint if empty.

## New Capability

After this iteration, a user can author a brand-new strategy end to end through
a guided interview that enforces the X-Matrix facilitation order, resume an
interrupted interview, and view the result as a read-only X-Matrix — all without
any LLM. This proves the authoring workflow and the write-side of the domain
model before LLM-assisted extraction is added in iteration 003.

## Validation Plan

- Run the new migration and confirm existing/seeded data is marked `:complete`.
- Run `dev check` and ensure it passes with zero warnings.
- Manually:
  - Visit `/`; confirm the three choices and that the example link shows the
    seeded matrix.
  - Start an interview; walk all 9 steps plus review; confirm each step persists
    and that Tactics cannot be reached before Evidence.
  - Reload mid-interview and confirm data and step are preserved.
  - Leave and resume from `/`.
  - Finish and confirm the new strategy renders as a read-only matrix with all
    five element types and at least one visible correlation strength.

## Risks / Follow-ups

- Incremental persistence creates partial/draft strategies in the database;
  without a management UI these can accumulate. Acceptable for the prototype; a
  later iteration can add listing/cleanup.
- Correlation grids grow with the number of elements; very large grids may be
  awkward in a dropdown-per-cell layout. Acceptable at prototype scale.
- The single-strategy `/` view becomes a per-id route here; when multi-strategy
  management arrives it will need a proper index.
- Once the faithful-layout view rework lands, `/strategies/:id` should adopt it;
  keep matrix rendering separable from the interview code.
- Validation strictness (empty element steps) may need tuning after first use.
