Goal: Validate that an iteration plan is ready for implementation
Run ID: 01KSRRV2F1ZN70WMP91R84S2A8
Pipeline progress: 3 of 15 stages completed

## Stage: read_plan
- Status: succeeded
- Handler: command
- Script: `PLAN_PATH='docs/iterations/004-openrouter-llm-provider/plan.md'
if [ ! -f "$PLAN_PATH" ]; then
  echo "Plan file not found: $PLAN_PATH" >&2
  exit 1
fi
printf 'PLAN_PATH=%s\n\n' "$PLAN_PATH"
sed -n '1,260p' "$PLAN_PATH"`
- Output:
  ```
  (127 lines omitted)
     - Create `docs/iterations/004-openrouter-llm-provider/developer-setup.md`.
     - Document local env vars:
       - `OPENROUTER_API_KEY=...`;
       - optional `OPENROUTER_MODEL=openai/gpt-oss-120b:free`.
     - Document that no key means scripted fallback.
     - Mention that `.local/secrets.envrc` is the intended local-only place for secrets in this repo.
  
  8. Validate.
     - Run targeted tests while implementing.
     - Run `mix precommit` before completion.
     - Manually start the app with `OPENROUTER_API_KEY` configured and verify an AI-enabled chat turn returns a response.
     - Optionally verify a tool-call response with the free model in an IEx/manual adapter call, without adding a permanent external-network test.
  
  ## Open Technical Decisions
  
  None known. The spike selected `openai/gpt-oss-120b:free` as the default free model and confirmed OpenRouter's OpenAI-compatible chat completions API supports the response shapes this app needs.
  
  ## New Capability
  
  After this iteration, Matt can test the existing AI-assisted interview using OpenRouter and a free model instead of needing Anthropic credits. The app will still work without any LLM key through the scripted guide.
  
  ## Validation Plan
  
  Automated validation:
  
  - Unit or adapter-level tests cover parsing normal assistant content and `propose_elements` tool calls.
  - LiveView tests cover provider selection with an OpenRouter key, no-key fallback, and proposal-card behaviour using a fake adapter.
  - Existing interview tests continue to pass without any real provider key.
  - `mix precommit` passes.
  
  Manual validation:
  
  1. Ensure `.local/secrets.envrc` contains `OPENROUTER_API_KEY=...` and direnv has loaded it.
  2. Start the development environment.
  3. Start a new interview with AI enabled.
  4. Send a chat message.
  5. Confirm that the app receives an AI facilitator response from OpenRouter.
  6. Confirm that removing/unsetting the key results in scripted fallback with a clear notice.
  
  Stop condition:
  
  - The app's active AI path uses OpenRouter successfully when configured, falls back when not configured or on provider error, and `mix precommit` passes.
  
  ## Risks / Follow-ups
  
  - Free OpenRouter models may be rate-limited, temporarily unavailable, or vary in tool-calling quality. The scripted fallback mitigates this.
  - Model output quality may be worse than Claude for facilitation. This iteration is about provider viability, not prompt quality.
  - OpenRouter response formats may vary by model. Keep parsing defensive and covered by tests.
  - Anthropic remains in the codebase but inactive; a future cleanup can make providers configurable by name or remove unused adapters.
  - Follow-up iteration 005 should address the product problem discovered in exploratory testing: a focused True North agreement flow with multiple candidate statements, feedback/refinement rounds, persisted section session state, and explicit submission of agreed structured data.
  ```

## Stage: fork
- Status: succeeded
- Handler: parallel
- Notes: Parallel node dispatched 3 branches (3 succeeded, 0 failed)

## Stage: merge
- Status: succeeded
- Handler: parallel.fan_in
- Notes: Selected best candidate: claude_review

## Current context
| Key | Value |
|-----|-------|
| parallel.branch_count | 3 |
| parallel.fan_in.best_head_sha | d0b59edf09c0e33ff5dec1be496149d04d34712b |
| parallel.fan_in.best_id | claude_review |
| parallel.fan_in.best_outcome | succeeded |
| parallel.results | [{"id":"gemini_review","status":"succeeded","head_sha":"8db641eb64648a7dcfc459ca89e3b12f13d5a17b"},{"id":"claude_review","status":"succeeded","head_sha":"d0b59edf09c0e33ff5dec1be496149d04d34712b"},{"id":"codex_review","status":"succeeded","head_sha":"e9a7dc2e8bbf2ebf15b53781f6afa21a22ad68a8"}] |


You are Claude Opus acting as the repair coordinator for an iteration plan validation loop.

Use the plan text and the three independent model reviews in context:

- Gemini review
- Claude review
- Codex/GPT review

Your job in this stage is to decide whether the plan is ready, needs only obvious editorial/structural correction, or needs human product/technical decisions before it can be ready.

Readiness standard:

A plan is READY only if an engineer can begin implementation without first resolving material product/business decisions or material technical design decisions, and if a reviewer can objectively validate success at the end.

A plan is NOT READY if any of these are true:

- The goal is materially ambiguous.
- The scope is too broad or lacks a smallest useful slice.
- Acceptance criteria are not concrete/testable enough.
- Important business decisions remain open.
- Implementation steps require major technical choices that are not made.
- The expected new capability or success validation is unclear.

Correction policy:

Codex may only be asked to make obvious plan edits that do not require judgment calls, such as:

- tightening wording without changing meaning
- reorganizing existing content into clearer sections
- turning already-stated expectations into objective acceptance criteria
- making implicit boundaries explicit when the plan already clearly implies them
- removing duplication or contradiction when the intended meaning is obvious

Do not ask Codex to invent product policy, scope, UX, domain, data-model, integration, or technical-design decisions. If the plan needs those decisions, fail the validation and raise them for Matt.

Synthesis instructions:

1. Compare the three reviews.
2. Identify consensus findings.
3. Correct reviewer findings that are wrong, too vague, duplicated, or not actually blocking.
4. Decide whether the plan is already ready, needs only obvious edits, or needs Matt's input.
5. If only obvious edits are needed, produce a concrete repair brief for Codex.
6. If Matt's input is needed, do not produce a repair brief as if Codex can solve it; list the decisions/questions clearly.

Return a Markdown report with:

1. Provisional decision: READY, OBVIOUS FIXES NEEDED, or NEEDS MATT
2. Consensus findings: 3-6 bullets
3. Corrected findings: reviewer findings you changed, downgraded, combined, or rejected
4. Blocking gaps: numbered list, each with why it blocks implementation
5. Codex repair brief: exact instructions for obvious edits only, or "None"
6. Questions for Matt: decisions that need human input, or "None"
7. Validation checklist: what to check after any Codex update

At the end of your response, include one final JSON object for workflow routing. It must be the last thing in the response.

If the plan is already READY:

{"context_updates":{"plan_ready":true,"plan_needs_fix":false,"plan_needs_human":false}}

If the plan is NOT READY but Codex should apply only obvious fixes:

{"context_updates":{"plan_ready":false,"plan_needs_fix":true,"plan_needs_human":false}}

If the plan is NOT READY because Matt needs to answer questions or make decisions:

{"context_updates":{"plan_ready":false,"plan_needs_fix":false,"plan_needs_human":true}}
