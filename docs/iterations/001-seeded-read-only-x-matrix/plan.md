# Seeded Read-only X-Matrix

Date: 2026-05-26
Status: ready

## Goal

Create a real Phoenix application, with no authentication, that renders a seeded read-only X-Matrix for a multi-agency homelessness strategy.

## Background / Context

This project is a prototype Phoenix app for helping people build, view, and track strategy using Karl Scotland's X-Matrix / TASTE model. Before building editing, interview, LLM, or tracking features, we want to prove the most basic product surface: a recognizable X-Matrix visualization backed by a real persisted strategy model.

The first slice should therefore dogfood the domain model without making the app meta. It will seed a plausible public-sector/nonprofit example: a multi-agency partnership strategy to reduce homelessness.

The TASTE model includes:

- True North: the orienting direction.
- Aspirations: ambitious outcomes/results.
- Strategies: guiding policies or enabling constraints.
- Evidence: leading indicators that show whether progress is happening.
- Tactics: concrete actions, initiatives, or experiments.

This iteration should define Evidence before Tactics in the seeded example, reflecting the X-Matrix facilitation guidance that evidence should not merely justify preselected tactics.

## Scope

### In scope

- Generate a Phoenix application in this repository.
- Use Phoenix LiveView, Ecto/Postgres, and Tailwind.
- Add `phoenix_test` for LiveView/browser-style tests.
- Add a `dev check` script suitable for the project.
- Create database schema for a single seeded strategy model, including:
  - strategy container or equivalent root record;
  - TASTE elements: True North, Aspirations, Strategies, Evidence, Tactics;
  - correlations between relevant element pairs.
- Store TASTE elements in a generic strategy element structure, with an element type field.
- Store correlations between elements with a strength field.
- Seed one multi-agency homelessness reduction strategy in `priv/repo/seeds.exs`.
- Render `/` as a read-only X-Matrix visualization.
- Include all TASTE sections in the visualization.
- Show correlation strengths for:
  - Strategies → Aspirations;
  - Evidence → Aspirations;
  - Tactics → Strategies;
  - Tactics → Evidence.
- Add automated tests using `phoenix_test` that verify the seeded X-Matrix renders.

### Out of scope

- Authentication or user accounts.
- Multiple strategy workspaces exposed in the UI.
- Creating, editing, deleting, or rearranging strategy elements.
- Interview flow.
- LLM integration.
- Tracking/review loop.
- Automated metric ingestion.
- Polished or pixel-perfect X-Matrix design.
- Cucumber/feature files.

## Acceptance Criteria

- The Phoenix application starts successfully and connects to Postgres.
- The database can be created, migrated, and seeded without errors.
- Visiting `/` returns an HTTP 200 response.
- The page at `/` displays the seeded homelessness reduction strategy by name/title.
- The page renders at least one element of each of the five types: True North, Aspiration, Strategy, Evidence, and Tactic.
- The page renders at least one correlation between two elements, displaying its strength (e.g., weak, medium, strong).
- At least two distinct correlation strengths are visually distinguishable on the page.
- The layout uses a grid or equivalent structure with distinct regions/quadrants for the element types, recognizable as an X-Matrix format (four quadrants around a center correlation area).
- The page is read-only: no forms, edit buttons, or mutation endpoints exist.
- `dev check` passes (formatting, compilation with zero warnings, and tests).
- At least one `phoenix_test` test verifies the seeded content is rendered at `/`.

## Open Business Decisions

None known.

## Implementation Plan

1. Generate the Phoenix app in this repository with LiveView, Ecto/Postgres, and Tailwind.
2. Add a project-level `dev check` script that runs the expected formatting, compile, and test checks for the Phoenix app.
3. Add `phoenix_test` and configure tests to use it.
4. Create the core strategy data model:
   - a root strategy table, such as `strategies`;
   - a generic `strategy_elements` table with a type field for `true_north`, `aspiration`, `strategy`, `evidence`, and `tactic`;
   - a `strategy_correlations` table linking two strategy elements with a strength and optional rationale.
5. Create context functions for loading the seeded strategy with its elements and correlations.
6. Add seeds for one multi-agency homelessness reduction strategy.
7. Build a read-only LiveView or controller-backed page at `/` that loads the seeded strategy.
8. Render the strategy as a rough X-Matrix using HTML/CSS/Tailwind. Prefer a simple, maintainable grid over custom drawing.
9. Add `phoenix_test` tests for the home page and seeded content.
10. Run and fix `dev check` until it passes.

## Open Technical Decisions

- Exact Phoenix app module/name is not yet chosen. Use a reasonable project name derived from `x-matrix`, such as `XMatrix`.
- Exact X-Matrix layout implementation is open. A CSS grid is preferred for the prototype.
- Exact correlation strength values are open, but should support at least `none`, `weak`, `medium`, and `strong` or an equivalent display.

## New Capability

After this iteration, we can run a real Phoenix app and view a persisted, seeded X-Matrix strategy at `/`. This gives us a concrete product surface for evaluating the domain model and visual representation before adding editing, interview, LLM, or tracking features.

## Validation Plan

- Run the generated Phoenix setup/database commands and seed the database.
- Run `dev check` and ensure it passes.
- Run automated tests, including `phoenix_test` coverage for `/`.
- Manually visit `/` and confirm:
  - the homelessness strategy appears;
  - at least one element of each of the five types (True North, Aspiration, Strategy, Evidence, Tactic) is visible;
  - at least one correlation is displayed with a visible strength indicator, and at least two distinct strengths are distinguishable;
  - the layout has distinct regions for each element type arranged in an X-Matrix format (four quadrants with a center correlation area);
  - the page is read-only.

## Risks / Follow-ups

- The first X-Matrix visualization may be visually rough. That is acceptable if it is recognizable and useful enough for feedback.
- The generic element/correlation schema may need refinement once editing and interview flows are added.
- The seeded strategy content may need domain review later; for this iteration it only needs to be plausible enough to exercise the model.
- Future iterations should add structured interview flow, LLM-assisted extraction, coherence checks, and tracking/review support.
