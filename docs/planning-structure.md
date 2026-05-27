# Planning document structure evaluation

## Current state

The repo currently has two top-level planning/research files:

- `PLAN.md` — prototype plan for the Phoenix strategy interview app.
- `karl-scotland-xmatrix-research.md` — research notes on Karl Scotland's X-Matrix / TASTE model.

The repo now also has local Pi skills:

- `.pi/skills/iteration-planning/SKILL.md`
- `.pi/skills/iteration-implementation/SKILL.md`

Those skills expect iteration plans to live under `docs/iterations/`.

## Recommended structure

Use top-level docs for durable product knowledge, and `docs/iterations/` for executable slices of work.

```text
.pi/
  skills/
    iteration-planning/
      SKILL.md
    iteration-implementation/
      SKILL.md

docs/
  planning-structure.md
  research/
    karl-scotland-xmatrix.md
  product/
    prototype-plan.md
    domain-model.md
    interview-design.md
    llm-contract.md
  adr/
    001-use-phoenix-liveview.md
  iterations/
    README.md
    001-strategy-model-and-manual-editor/
      plan.md
    002-structured-interview/
      plan.md
    003-llm-assisted-extraction/
      plan.md
```

## Roles of each area

### `docs/research/`

Use for source material and interpretation.

Examples:

- X-Matrix / TASTE research
- Hoshin Kanri references
- competitor or template research
- notes from user interviews

These docs should explain what we learned, not commit us to building anything.

### `docs/product/`

Use for durable product decisions and design artifacts.

Recommended starting docs:

- `prototype-plan.md` — move the current `PLAN.md` here.
- `domain-model.md` — the TASTE entities, correlations, reviews, observations, and lifecycle.
- `interview-design.md` — stages, prompts, examples, and rules for turning answers into model elements.
- `llm-contract.md` — structured JSON schemas, guardrails, prompt patterns, and validation expectations.

These docs should remain true across multiple iterations.

### `docs/adr/`

Use for architectural decisions that should not be rediscovered later.

Likely ADRs:

- Use Phoenix LiveView for the prototype.
- Store strategy elements in a generic `strategy_elements` table rather than separate tables per TASTE type.
- Use structured LLM outputs with user confirmation before persistence.

### `docs/iterations/`

Use for implementation-ready slices. This should follow the copied `iteration-planning` skill.

Each iteration gets its own folder:

```text
docs/iterations/001-topic-slug/plan.md
```

Each plan should include:

- goal
- background/context
- in scope / out of scope
- acceptance criteria
- open business decisions
- implementation plan
- open technical decisions
- new capability
- validation plan
- risks/follow-ups

Maintain `docs/iterations/README.md` as the index and source of truth for which plans are ready.

## Suggested first iterations

### 001 — Strategy model and manual editor

Build the app without LLM support first:

- Phoenix project setup
- core Ecto schema
- workspace creation
- manual CRUD for TASTE elements
- manual correlations
- simple list/matrix views

This proves the domain model before adding conversational complexity.

### 002 — Structured interview without LLM

Add the guided interview state machine with fixed prompts. Let users convert answers into model elements manually.

This proves the workflow before adding LLM extraction.

### 003 — LLM-assisted extraction

Add structured LLM calls per interview stage. The LLM proposes elements, questions, warnings, and summaries. The user confirms all changes.

This proves the AI assistive layer without letting it own the strategy.

### 004 — Coherence and correlation assistance

Add deterministic checks and LLM-suggested correlations.

### 005 — Tracking and review loop

Add tactic status, evidence observations, review entries, and review summaries.

## Recommended immediate cleanup

1. Move `PLAN.md` to `docs/product/prototype-plan.md`.
2. Move `karl-scotland-xmatrix-research.md` to `docs/research/karl-scotland-xmatrix.md`.
3. Create `docs/iterations/README.md`.
4. Create the first iteration folder: `docs/iterations/001-strategy-model-and-manual-editor/`.
5. Use the copied `iteration-planning` skill to turn the prototype plan into an implementation-ready `plan.md`.

## Note about Fabro

The copied skills refer to Fabro workflows under `.fabro/workflows/`. This repo does not currently have those workflows. Until they exist, the planning skill is still useful for structure, but its validation/submission steps will be blocked.
