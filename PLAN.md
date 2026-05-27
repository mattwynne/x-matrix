# Prototype plan: Strategy Interview + X-Matrix Phoenix App

## Purpose

Build a Phoenix prototype that interviews a user to develop a coherent strategy, maps the answers into Karl Scotland’s X-Matrix/TASTE model, presents the strategy through several useful views, and helps the user track progress over time.

The prototype should prove three things:

1. A structured interview can help a user express a strategy clearly.
2. The interview output can populate an X-Matrix-style model without becoming vague or overcomplicated.
3. Multiple views of the same model can help the user understand, communicate, and manage the strategy.

## Product hypothesis

People struggle to move from ambition to coherent strategic action. A guided, conversational tool can help them clarify direction, choices, evidence, and experiments, then keep the strategy alive through regular review.

## Core model

Use the TASTE framing:

- **True North**: the enduring direction or orienting principle.
- **Aspirations**: ambitious outcomes or results the user hopes to achieve.
- **Strategies**: guiding policies or enabling constraints that shape choices.
- **Evidence**: leading indicators that show whether progress is happening.
- **Tactics**: concrete actions, initiatives, or experiments.

Also model correlations between:

- Strategies and Aspirations
- Evidence and Aspirations
- Tactics and Strategies
- Tactics and Evidence

Each correlation can be:

- none
- weak
- medium
- strong

## Prototype scope

### In scope

- Phoenix web app with authentication optional or minimal.
- One strategy workspace per user/session.
- Structured interview flow.
- LLM-assisted question generation, summarization, and refinement.
- Persistence of the strategy model.
- X-Matrix view.
- List/detail views for each model element.
- Review/tracking view for evidence and tactics.
- Basic edit/refine loop.

### Out of scope for first prototype

- Multi-user collaboration.
- Permissions and organizations.
- Complex dashboards.
- Integrations with Jira, GitHub, Linear, Slack, etc.
- Automated metric ingestion.
- Rich presentation/export formats beyond basic HTML or Markdown.

## User journey

### 1. Create a strategy

The user starts a new strategy workspace and gives it a name, context, and timeframe.

Example fields:

- Strategy name
- Organization/team/product
- Time horizon
- Current situation
- Important constraints

### 2. Interview

The app guides the user through a structured interview. The LLM may adapt wording and ask follow-up questions, but the flow remains anchored to the model.

Recommended interview order:

1. True North
2. Current situation
3. Aspirations
4. Strategies
5. Evidence
6. Tactics
7. Correlations
8. Risks, assumptions, and open questions

Use Scotland’s practical ordering: define Evidence before Tactics to reduce confirmation bias.

### 3. Synthesis

After each section, the app proposes structured candidates for the model. The user can accept, edit, split, merge, or discard them.

Example:

> “I heard three possible Aspirations. Which should we keep?”

### 4. Strategy views

Once populated, the app presents the strategy through several views:

- **X-Matrix view**: classic matrix layout with correlations.
- **Narrative view**: a plain-English strategic story.
- **Assumptions view**: key hypotheses behind tactics and evidence.
- **Evidence view**: leading indicators and review notes.
- **Tactics board**: actions/experiments with status.
- **Coherence view**: warnings about orphaned or weakly connected items.

### 5. Tracking and review

The user can run periodic reviews:

- Update tactic status.
- Record evidence observations.
- Note what changed.
- Ask whether strategies or aspirations need revision.
- Generate a short review summary.

## LLM design

The LLM should assist, not own, the strategy.

### Responsibilities

- Ask concise follow-up questions.
- Summarize messy answers.
- Propose candidate model elements.
- Detect ambiguity, duplication, and weak causality.
- Suggest correlations with reasons.
- Generate narrative summaries.
- Generate review prompts.

### Guardrails

- The app owns the schema and flow.
- The LLM returns structured JSON for model updates.
- The user confirms all changes before persistence.
- The LLM should avoid inventing facts.
- The LLM should distinguish user-stated facts from inferred suggestions.

### Suggested structured output

```json
{
  "summary": "Short summary of what the user said.",
  "candidates": [
    {
      "type": "aspiration",
      "title": "Improve customer retention",
      "description": "Increase repeat usage by making the product more habit-forming.",
      "confidence": "medium",
      "source": "user_stated"
    }
  ],
  "follow_up_questions": [
    "What would make this aspiration feel meaningfully ambitious?"
  ],
  "warnings": [
    "This aspiration sounds like a tactic rather than an outcome."
  ]
}
```

## Phoenix architecture

### Suggested stack

- Phoenix 1.7+
- LiveView for the interview and interactive views
- Ecto/Postgres for persistence
- Oban for background LLM calls if needed
- Req or Finch-based client for LLM API calls
- Tailwind for UI

### Contexts

#### `Accounts`

Optional for prototype. Could start with anonymous sessions.

#### `Strategy`

Owns the core domain model:

- workspaces
- elements
- correlations
- review entries
- evidence observations
- tactic updates

#### `Interviews`

Owns interview state:

- sessions
- turns
- prompts
- extracted candidates
- accepted/rejected suggestions

#### `LLM`

Owns provider calls and structured response validation:

- prompt templates
- JSON schema validation
- retries
- logging

## Data model

### `strategy_workspaces`

- id
- title
- subject
- timeframe
- context
- inserted_at
- updated_at

### `strategy_elements`

- id
- workspace_id
- type: true_north | aspiration | strategy | evidence | tactic
- title
- description
- position
- status
- metadata map
- inserted_at
- updated_at

### `strategy_correlations`

- id
- workspace_id
- from_element_id
- to_element_id
- strength: none | weak | medium | strong
- rationale
- inserted_at
- updated_at

### `interview_sessions`

- id
- workspace_id
- current_stage
- status
- inserted_at
- updated_at

### `interview_turns`

- id
- interview_session_id
- role: user | assistant | system
- stage
- content
- structured_output map
- inserted_at

### `review_entries`

- id
- workspace_id
- review_date
- summary
- decisions
- inserted_at

### `element_updates`

- id
- element_id
- review_entry_id
- status
- observation
- value
- inserted_at

## Interview stages

### Stage 1: Context

Goal: understand what strategy is being created and why.

Prompts:

- What are we building a strategy for?
- What is the time horizon?
- What is happening now that makes strategy important?
- Who needs to understand or act on this strategy?

### Stage 2: True North

Goal: identify the orienting direction.

Prompts:

- What direction should decisions consistently move you toward?
- What should remain true even if plans change?
- What would you refuse to sacrifice for short-term gain?

### Stage 3: Aspirations

Goal: define ambitious outcomes.

Prompts:

- What results would make this strategy worth the effort?
- What would be meaningfully different at the end of the horizon?
- Which aspirations are ambitious but still plausible?

### Stage 4: Strategies

Goal: define guiding policies and choices.

Prompts:

- What choices will focus attention?
- What will you do differently from default behavior?
- What constraints will help people decide what to do and not do?

### Stage 5: Evidence

Goal: define leading indicators before jumping to tactics.

Prompts:

- What would you expect to see earlier if the strategy were working?
- What behavior, capability, or outcome should increase or decrease?
- What evidence would challenge your strategy?

### Stage 6: Tactics

Goal: identify coherent actions and experiments.

Prompts:

- What experiments could generate the evidence?
- What work would make the strategies real?
- What is the smallest useful next step?

### Stage 7: Correlations

Goal: test coherence.

Prompts:

- Which strategies support which aspirations?
- Which evidence indicates progress toward which aspirations?
- Which tactics implement which strategies?
- Which tactics should generate which evidence?

### Stage 8: Risks and assumptions

Goal: expose uncertainty.

Prompts:

- What must be true for this strategy to work?
- Where is confidence lowest?
- What could make this strategy obsolete?

## Views/facets

### X-Matrix view

A visual summary of the full model and correlations. For the prototype, this can be a simplified grid rather than a perfect X-shaped diagram.

### Narrative view

A short strategy story:

- We are oriented by...
- We aspire to...
- We will focus on...
- We expect to see...
- Therefore we will try...

### Coherence view

Highlight problems:

- Aspirations with no supporting strategy.
- Strategies with no evidence.
- Tactics with no strategy.
- Tactics with no expected evidence.
- Too many strong correlations.
- Vague or duplicate items.

### Tracking view

Show:

- tactic status
- latest evidence observations
- review history
- open questions
- changes since last review

### Presentation view

A clean read-only page suitable for sharing or discussing in a meeting.

## Build phases

### Phase 0: Project setup

- Create Phoenix app.
- Add Postgres config.
- Add Tailwind/LiveView defaults.
- Create initial contexts and migrations.
- Add seed data for a sample strategy.

### Phase 1: Manual model editor

Build the app without the LLM first.

- CRUD for strategy workspaces.
- CRUD for TASTE elements.
- CRUD for correlations.
- Basic X-Matrix/list views.

Success criterion: a user can manually create and view a complete strategy model.

### Phase 2: Structured interview without LLM

- Add interview session state machine.
- Add fixed prompts for each stage.
- Capture user answers.
- Let user manually convert answers into model elements.

Success criterion: a user can complete the interview and populate the model.

### Phase 3: LLM-assisted extraction

- Add LLM client.
- Add prompt templates per interview stage.
- Parse structured JSON responses.
- Present candidate elements for user approval.
- Store accepted candidates as model elements.

Success criterion: the LLM can propose useful, editable model elements from interview answers.

### Phase 4: Coherence and correlation assistance

- Ask LLM to propose correlations with rationales.
- Add deterministic coherence checks.
- Show warnings and suggested improvements.

Success criterion: the app can identify weak or missing connections in the strategy.

### Phase 5: Tracking and review loop

- Add tactic status updates.
- Add evidence observations.
- Add periodic review entries.
- Generate review summaries.

Success criterion: the strategy becomes a living model, not a one-off document.

## Prototype risks

- The LLM may produce generic strategy language.
- The interview may feel too long.
- Users may confuse aspirations, strategies, evidence, and tactics.
- The X-Matrix view may be visually hard to implement.
- Tracking may become too manual to sustain.

## Mitigations

- Keep the schema strict.
- Ask for concrete examples.
- Prefer short interview loops with confirmation after each section.
- Use deterministic checks alongside LLM suggestions.
- Start with a simple matrix/list UI before investing in custom visualization.
- Make reviews lightweight: status, evidence, decision, next step.

## First milestone

Build a Phoenix LiveView prototype where a user can:

1. Create a strategy workspace.
2. Answer structured interview questions.
3. Accept/edit extracted TASTE elements.
4. View the resulting strategy as a narrative and simplified X-Matrix.
5. Add one review entry with tactic status and evidence observations.

