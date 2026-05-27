# LLM-led Conversational Interview

Date: 2026-05-27
Status: proposed (design)

## Goal

Turn the interview into an AI-facilitated chat: a scrolling conversation on the
left, a live "emerging matrix" summary on the right, and a TASTE progress
indicator across the top. An LLM facilitator runs the five element sections
conversationally — asking rich questions, proposing candidate items, and
reacting to what you write — while you stay in control: nothing is saved to your
strategy without explicit confirmation. The same chat works as a **free,
non-AI version** via a scripted guide, so the app runs (and tests pass) with no
API key.

## Background / Context

Iteration 002 built a guided interview as one-question-per-screen forms. Real
use surfaced two themes:

1. **It should feel conversational and contextual.** People are used to chat;
   they want to see their previous answers, get varied and encouraging prompts
   ("that's only one — typically we'd want 3 or 4; what else?"), know where
   "Continue" leads, and see progress.
2. **A blank sheet is hard, especially for strategies.** An LLM that proposes
   options — given the North Star and aspirations as context — would help. For
   strategies in particular, Karl Scotland recommends "even over" statements
   ("X even over Y", in the spirit of the Agile Manifesto). The two halves
   should be in **genuine tension** — both things you value — so the statement
   expresses a real priority, not a platitude.

This iteration adopts a chat interface and an optional LLM co-pilot. It pulls
forward what the roadmap called iteration 003 (LLM-assisted extraction), keeping
the roadmap's core principle: **the user confirms every change; the LLM never
silently owns the strategy.**

### Relationship to existing work

- **Supersedes** the stepped, one-question-per-screen *element* entry from 002.
- **Reuses** the structured per-source correlation rating screens, the read-only
  matrix at `/strategies/:id`, the homepage strategy list, and the cleaned-up
  layout.

## Scope

### In scope

- A chat interview UI at `/interview/:id`:
  - a transcript of facilitator and user messages;
  - a free-text input that submits on Enter;
  - an emerging-matrix panel: a running list grouped by TASTE section, showing
    **only confirmed items**;
  - a TASTE progress indicator (the five element stages, then relationships,
    then review).
- An **AI toggle** in the interview:
  - **ON** — an LLM facilitates the element sections, proposing items;
  - **OFF (free)** — a scripted guide asks the same questions; you type every
    answer; no LLM calls.
- LLM facilitation of the five **element** sections (True North, Aspirations,
  Strategies, Evidence, Tactics): a conversational message plus zero or more
  **structured element proposals** per turn.
- Proposals render as **suggestion cards** in the chat with **Add / Edit /
  Dismiss**. Adding persists via the existing context functions; editing lets
  you change the text first; dismissing discards. Typing your own item adds it
  directly. The matrix panel reflects only confirmed items.
- A pluggable `XMatrix.LLM` behaviour with two adapters:
  - `XMatrix.LLM.Anthropic` — Anthropic Messages API via `Req`, using tool-use
    so proposals are structured, not parsed from prose;
  - `XMatrix.LLM.Scripted` — deterministic guide used for free mode, tests, and
    as the no-key fallback.
- Graceful degradation: AI-on with no key (or an API error) shows a friendly
  notice and falls back to the scripted guide / manual entry; you can always
  continue by typing.
- Transcript persistence so a draft resumes with its history.
- "Even over" guidance (genuine tension) encoded in the facilitator's
  instructions and in the on-screen help for the Strategies section.
- Relationship sections continue as the structured per-source rating UI from
  002, reached after the element sections.

### Out of scope

- LLM-proposed **correlation** strengths (correlations stay manual this
  iteration; the LLM may suggest them in a later one).
- Streaming token-by-token responses (v1 awaits the full reply with a
  "thinking…" indicator).
- Providers beyond the behaviour seam (only Anthropic + Scripted ship).
- Editing a strategy after it is marked complete.
- Voice or file input.
- Authentication / multi-user.

## Acceptance Criteria

- `/interview/:id` shows a chat transcript, a free-text input, an emerging-matrix
  panel (grouped by section, confirmed items only), and a TASTE progress
  indicator.
- With AI **OFF**, the scripted guide asks each section's question; typing an
  answer adds the item and it appears in the matrix panel; no LLM adapter call
  is made.
- With AI **ON** (key configured), a turn returns a facilitator message and may
  return one or more proposal cards; **Add** persists the item and updates the
  panel, **Dismiss** discards it, **Edit** lets the text change before adding.
- No proposal is persisted without an explicit Add.
- The facilitation order is enforced (element sections in TASTE order, then
  relationships, then review) regardless of LLM output.
- AI **ON** with no key, or on an API error, shows a notice and lets the user
  continue via the scripted guide / manual typing.
- A resumed draft restores the transcript and the confirmed matrix; the progress
  indicator reflects the saved stage.
- Relationship rating screens still function and persist correlations.
- Finishing marks the strategy complete and navigates to `/strategies/:id`.
- `dev check` passes with no API key (Scripted adapter), including new tests.

## Architecture

### LLM behaviour and adapters

- `XMatrix.LLM` behaviour, roughly:

  ```
  @callback facilitate(stage :: atom, conversation :: [message], snapshot :: map)
              :: {:ok, %{message: String.t(), proposals: [proposal]}} | {:error, term}
  ```

  where `proposal` is `%{type: element_type, title: String.t(), description: String.t() | nil}`
  and `snapshot` summarises confirmed elements (so the model has context).

- `XMatrix.LLM.Anthropic` builds a system prompt per stage (including the
  facilitation rules and the "even over" tension guidance for strategies),
  sends the conversation via `Req`, and declares a `propose_elements` tool so
  proposals return as structured tool input rather than free text.
- `XMatrix.LLM.Scripted` returns the next scripted question for the stage and no
  proposals — powering free mode and tests deterministically.

- Adapter choice: AI **OFF** → `Scripted`. AI **ON** → `Anthropic` when
  `ANTHROPIC_API_KEY` is set, else `Scripted` with a notice. Configured in
  `config/runtime.exs`; `:test` pins `Scripted`. Model is configurable,
  defaulting to a fast Claude (e.g. Haiku) since turns are short.

### Orchestration

The interview LiveView holds the conversation and the confirmed-element
assigns. On a user turn it persists the user message, calls the selected
adapter with the conversation + snapshot, persists the facilitator message, and
renders any proposal cards (transient — held in socket assigns for that turn,
not stored). Stage advances when the facilitator signals completion (an
`advance_stage` tool / scripted cue) **and** the user agrees, with a manual
"Move on" control as a backstop. After the last element stage, the flow hands
off to the structured correlation screens, then review.

### Confirmation

Proposal cards never touch the database until **Add**. Add (and manual typing)
go through the existing `Strategies.add_element/2`; the emerging-matrix panel is
rendered from confirmed elements, so it is always the source of truth.

## Data model

- New `strategy_messages` table: `strategy_id`, `role` (`Ecto.Enum`
  `[:assistant, :user]`), `content` (text), timestamps. Stores the transcript
  for display and as LLM context.
- `strategies.ai_assisted` (boolean, default based on key availability) — the
  toggle state, so resume keeps the chosen mode.
- Reuse `strategies.current_step` as the stage marker driving the progress
  indicator and the handoff to correlation screens.
- Proposal cards are **not** persisted (deliberate simplification): on resume
  the user sees the transcript and confirmed matrix and can ask again.

## Implementation outline (high level)

A detailed, test-first plan comes later via the writing-plans skill. The broad
shape:

1. Migration + schema: `strategy_messages`, `strategies.ai_assisted`.
2. `XMatrix.LLM` behaviour + `Scripted` adapter (drives free mode and tests).
3. Chat LiveView: transcript, input, emerging-matrix panel, progress indicator,
   AI toggle — wired to the `Scripted` adapter first (no network).
4. Proposal cards with Add / Edit / Dismiss; manual typing; confirmed-only panel.
5. Stage machine + handoff to existing correlation screens + review + finish.
6. `Anthropic` adapter via `Req` with tool-use; runtime adapter selection;
   error/no-key fallback and notice.
7. Transcript persistence and resume.

## Testing

All tests run against the `Scripted` adapter — no network or key required:

- Free mode: scripted question appears, typing adds an item, panel updates, no
  Anthropic call.
- Proposal cards (driven by a scripted/canned proposing adapter in test):
  Add persists and updates the panel; Dismiss discards; Edit changes text before
  adding.
- Order enforcement across stages; manual "Move on" backstop.
- Resume restores transcript, confirmed matrix, and stage.
- Correlation screens and finish still work end to end.

## Open decisions

- Default for `ai_assisted` on a brand-new draft: ON when a key is present, else
  OFF. (Proposed; confirm during planning.)
- Exact default Claude model and token budget. (Proposed: a fast/cheap model.)
- Whether the AI toggle is also offered on the homepage "Start" action or only
  inside the interview. (Proposed: inside the interview; homepage just starts a
  draft.)

## Risks / Follow-ups

- **Cost/latency** of LLM calls; mitigated by a fast model, short prompts, and
  free mode as default-safe. Streaming is a follow-up.
- **Prompt quality**: getting the facilitator to ask well and propose genuinely
  in-tension "even over" strategies will need iteration; the behaviour seam lets
  us tune the Anthropic adapter without touching the UI.
- **Two facilitation paths** (scripted vs LLM) share one UI; keep the stage
  machine and proposal-confirmation logic adapter-agnostic so they don't drift.
- **Transcript growth** as LLM context could raise token use on long
  interviews; summarise or window the conversation if needed (follow-up).
- LLM-suggested correlation strengths and editing completed strategies remain
  for later iterations.
