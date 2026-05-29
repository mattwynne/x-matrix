# True North Agreement Flow

Date: 2026-05-29
Status: ready

## Goal

Replace the current brittle True North chat with a focused agreement loop. A user should be able to converse with the AI facilitator, review multiple candidate True North statements, refine them through feedback, and explicitly submit one agreed statement to the X-Matrix before moving immediately to Aspirations.

The beneficiary is Matt as product tester and strategy-facilitation designer. This iteration should make the first section of the interview feel like an intentional collaborative agreement process rather than a generic chat where proposal cards can appear and disappear.

## Background / Context

Iterations 002 and 003 created the structured interview and LLM-led conversational interview. Iteration 004 switched the active LLM provider to OpenRouter so Matt can test the AI-assisted interview without Anthropic credits.

Exploratory testing showed that the current True North experience is the biggest product problem. The existing flow treats True North like every other element stage:

- a user message in non-AI mode is immediately saved as an element;
- AI mode can return transient proposal cards;
- proposal cards are generic element proposals;
- pending proposals live in LiveView assigns and are not restored on resume;
- adding a proposal saves it, but there is no explicit sense of reaching agreement on the True North statement.

The prior planning conversation established these product decisions for True North:

- True North should be a pithy statement plus a short unpacking explanation.
- The robot should be able to offer 2–3 alternative candidate phrasings.
- The user may give feedback and ask for refined candidates over multiple rounds.
- Only the accepted or edited candidate is submitted to the matrix.
- Submitting True North saves structured data and immediately advances to Aspirations.
- The True North agent session should be persisted as JSONB so returning to True North restores the same conversation and current candidates.
- The user may reopen and resubmit True North later; downstream work is left untouched and no warning is shown.

## Scope

### In scope

- True North only.
- Add a dedicated True North agreement mode for `chat:true_north`.
- Let the AI facilitator ask clarifying questions and propose 2–3 candidate True North statements when useful.
- Represent each candidate with:
  - `title` — the pithy True North statement;
  - `description` — one or two sentences unpacking the meaning.
- Let the user give feedback such as “shorter”, “less consultant-y”, “more ambitious”, or “combine the first two”.
- Let the user accept a candidate as-is.
- Let the user edit a candidate before submission.
- Persist the True North session state in Postgres as JSONB so the conversation and current candidates survive navigation, refresh, and draft resume.
- Save or update the single `:true_north` `strategy_elements` row only when the user explicitly submits an accepted/edited candidate.
- Immediately advance the draft to `chat:aspiration` after successful submission.
- If the user navigates back to True North later, restore the same session and allow further refinement and resubmission.
- If True North is changed after later sections have work, keep downstream aspirations, strategies, evidence, tactics, and correlations untouched.
- Keep the scripted/no-key fallback usable for True North, with deterministic candidate generation or a clear manual path that still supports explicit submission.
- Keep OpenRouter as the active AI provider when configured.
- Keep existing non-True-North stages working as they do now.

### Out of scope

- Redesigning Aspirations, Strategies, Evidence, or Tactics into agreement loops.
- Persisting section session state for every TASTE section, except insofar as a small reusable table/module is the simplest way to support True North.
- Changing relationship/correlation assistance.
- Deleting, resetting, warning about, or recalculating downstream work when True North changes.
- Streaming LLM responses.
- Provider admin UI, model selection UI, or end-user OpenRouter connection.
- Removing the generic proposal-card system for later stages.
- Completing or redesigning the whole matrix review experience.

## Acceptance Criteria

- Starting a new interview opens the True North agreement UI before Aspirations.
- The True North UI makes it clear that nothing is saved to the matrix until a candidate is explicitly submitted.
- Submitting a normal chat message during True North does not immediately create or update a `:true_north` element.
- With AI available, the facilitator can return multiple True North candidates in one turn.
- Candidate cards show both the pithy statement and the unpacking explanation.
- The user can give feedback on the candidates and receive a revised set without saving anything to the matrix.
- The user can accept a candidate and submit it as the True North.
- The user can edit a candidate’s statement and explanation before submitting it.
- Submitting a candidate creates the single True North element if none exists.
- Submitting a later candidate updates the existing single True North element rather than creating duplicates.
- After successful True North submission, the draft immediately advances to Aspirations.
- Returning to True North restores the prior True North conversation and current candidate set from persisted session state.
- Refreshing the page or resuming the draft also restores the True North session state.
- If the user changes True North after adding aspirations or other downstream work, downstream work remains unchanged and no warning is shown.
- With no OpenRouter key, True North remains usable through the scripted fallback and still requires explicit submission before saving.
- If the OpenRouter request fails, the LiveView shows the existing friendly fallback flash and continues without losing the persisted True North session state.
- Tests do not make real OpenRouter network calls.
- `mix precommit` passes.

## Open Business Decisions

None known.

## Implementation Plan

1. Add persisted section session state.
   - Generate a migration with `mix ecto.gen.migration`.
   - Add a small persistence model for strategy section sessions, recommended as a new table keyed by `strategy_id` and `section`, for example `strategy_section_sessions` with:
     - `strategy_id` foreign key;
     - `section` string or enum-like string, initially `true_north`;
     - `state` JSONB/map;
     - timestamps.
   - Add a unique index on `strategy_id, section`.
   - Keep submitted True North as normalized `strategy_elements`; use JSONB only for agent/session working state.

2. Add context functions in `XMatrix.Strategies`.
   - Fetch or initialize the True North session for a draft.
   - Update the session state after user messages, assistant replies, candidate proposals, edits, dismissals, and submission.
   - Keep these functions draft-safe and testable.

3. Define the True North session state shape.
   - Store enough JSON to restore the interaction, such as:
     - conversation messages relevant to the True North agent;
     - current candidates with stable IDs, title, description, and optional status;
     - selected/editing candidate if useful;
     - section status such as `in_progress` or `submitted`;
     - provider/model metadata when available.
   - Do not feed downstream sections the whole raw session by default; use only the submitted True North element as context.

4. Add a dedicated True North agreement branch in `InterviewLive`.
   - For `chat:true_north`, render a focused agreement UI instead of the generic proposal-card interaction where needed.
   - Preserve `<Layouts.app flash={@flash}>` wrapping and existing LiveView conventions.
   - Add explicit DOM IDs for key forms/buttons for tests.
   - Ensure normal chat messages are persisted to the True North session and transcript as appropriate, but do not save matrix elements until submission.

5. Adapt facilitator calls for True North.
   - Use the configured LLM adapter when OpenRouter is available.
   - Prompt the facilitator specifically for True North agreement: ask useful questions, propose 2–3 candidates, respond to feedback, and never claim anything is saved.
   - Use structured proposals/candidates rather than parsing prose.
   - Keep a deterministic scripted/fake path for tests and no-key fallback.

6. Add candidate interactions.
   - Render multiple candidate cards with statement and explanation.
   - Support feedback/refinement without saving.
   - Support accept-and-submit.
   - Support edit-before-submit.
   - On submit, save/update the single `:true_north` element and advance `current_step` to `chat:aspiration`.

7. Preserve later-stage behaviour.
   - Aspirations, Strategies, Evidence, Tactics, correlations, and review should continue using the current flow unless they receive submitted True North context.
   - Existing proposal-card tests for later stages should keep passing.

8. Add tests.
   - Context tests for section session create/update/restore.
   - LiveView tests for:
     - chat during True North does not save an element;
     - candidate cards render;
     - feedback/refinement updates candidates without saving;
     - accept/submit creates the single True North and advances to Aspirations;
     - edit/submit updates title and description;
     - returning/resuming restores persisted session state;
     - resubmitting updates the existing True North and leaves downstream work unchanged;
     - no-key/provider-error fallback remains usable.
   - Use fake adapters; no external network calls.

## Open Technical Decisions

None known. The plan recommends a `strategy_section_sessions` table with JSONB `state` rather than a single JSONB column on `strategies` because it keeps agent working state separate from the core strategy row and can be reused later without committing this iteration to redesign every section.

## New Capability

After this iteration, Matt can use the app to reach an explicit, revisable True North agreement: the AI and user can explore alternatives, refine candidate phrasings, preserve the working conversation across navigation/resume, and submit one structured True North before moving on.

## Validation Plan

Automated validation:

- Unit/context tests cover True North section session persistence and restoration.
- LiveView tests cover the True North agreement flow, candidate interactions, explicit submission, immediate advance, resubmission, and fallback paths.
- Existing interview, proposal-card, and matrix display tests continue to pass.
- Tests use fake adapters and do not make real OpenRouter calls.
- `mix precommit` passes.

Manual validation:

1. Start the app with `OPENROUTER_API_KEY` configured.
2. Start a new interview.
3. Confirm the first section is the True North agreement UI.
4. Answer conversationally.
5. Confirm the facilitator can propose multiple candidate True North statements.
6. Give feedback and confirm revised candidates appear.
7. Accept or edit one candidate and submit it.
8. Confirm the single True North is saved and the interview immediately advances to Aspirations.
9. Navigate back to True North and confirm the prior conversation/candidates are restored.
10. Change and resubmit True North; confirm downstream work is not deleted.
11. Repeat with no OpenRouter key and confirm the scripted fallback still supports explicit submission.

See `manual-demo-script.md` for a concise smoke/demo checklist.

## Risks / Follow-ups

- This introduces persisted agent working state. Keep it clearly separate from normalized strategy elements to avoid making JSONB the source of truth for submitted domain data.
- Free OpenRouter models may produce weak candidate phrasing or inconsistent tool calls. Tests should use fake adapters; manual testing should expect model variance.
- The first dedicated agreement UI may reveal patterns we want for later TASTE sections. Defer generalization until True North is working well.
- Restoring old candidate IDs from JSONB needs care so LiveView events remain stable after refresh/resume.
- Future iterations can apply the same agreement-loop pattern to Aspirations, Strategies, Evidence, or Tactics if the True North pattern works.
