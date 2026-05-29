# OpenRouter LLM Provider

Date: 2026-05-28
Status: ready

## Goal

Switch the active AI facilitator integration from Anthropic to OpenRouter so Matt can keep testing the conversational interview without paying for Anthropic credits. The existing interview behaviour should remain the same from a user's point of view: when AI is available the app can ask contextual questions and return structured proposal cards; when AI is unavailable the app falls back to the scripted guide.

The beneficiary is Matt as the product tester/developer. This is an enabling iteration for the next product cleanup iteration, which will redesign the True North agreement flow.

## Background / Context

Iteration 003 added an LLM-led interview backed by `XMatrix.LLM.Anthropic`, selected when `ANTHROPIC_API_KEY` is configured. Matt has run out of Anthropic credits and wants to test using OpenRouter with a free model instead.

A local spike confirmed that OpenRouter works with the existing intended integration shape:

- `OPENROUTER_API_KEY` is visible through the local direnv setup.
- `https://openrouter.ai/api/v1/chat/completions` accepted chat completion requests.
- The free model `openai/gpt-oss-120b:free` returned responses with `usage.cost: 0`.
- JSON response mode worked.
- OpenAI-compatible tool/function calling worked and returned structured `propose_elements` tool calls with `type`, `title`, and `description` fields.

The current product flow has known UX problems, especially in True North. Those are deliberately deferred so this iteration only changes provider infrastructure.

## Scope

### In scope

- Add `XMatrix.LLM.OpenRouter` implementing the existing `XMatrix.LLM` behaviour.
- Use the already-available `Req` library for HTTP calls.
- Configure OpenRouter at runtime with:
  - `OPENROUTER_API_KEY`;
  - `OPENROUTER_MODEL`, defaulting to `openai/gpt-oss-120b:free`.
- Call OpenRouter's OpenAI-compatible chat completions endpoint:
  - `https://openrouter.ai/api/v1/chat/completions`.
- Use tool/function calling so the adapter can return the existing structured proposal shape:
  - `%{type: atom(), title: String.t(), description: String.t() | nil}`.
- Make OpenRouter the default active AI provider when AI is enabled and an OpenRouter key is configured.
- Keep the scripted adapter as the fallback when:
  - no OpenRouter key is configured;
  - OpenRouter returns an error;
  - tests run.
- Keep `XMatrix.LLM.Anthropic` in the codebase, but inactive by default.
- Update provider-specific naming, copy, config helpers, and tests that currently assume Anthropic is the active provider.
- Add a short developer setup note in this iteration folder explaining `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`, and the no-key fallback.
- Capture the next iteration topic, True North agreement flow, in the iteration index as proposed follow-on work.

### Out of scope

- Redesigning the True North UX.
- Persisting section agent sessions as JSONB.
- Changing the current proposal-card interaction model.
- Changing TASTE stage progression.
- LLM-assisted correlation ratings.
- Streaming responses.
- Removing the Anthropic adapter.
- OAuth or end-user OpenRouter account connection.
- Any production billing, quota management, or provider admin UI.

## Acceptance Criteria

- With `OPENROUTER_API_KEY` configured and AI enabled on a draft strategy, submitting a chat message calls `XMatrix.LLM.OpenRouter`, not Anthropic.
- With `OPENROUTER_MODEL` unset, the OpenRouter adapter uses `openai/gpt-oss-120b:free`.
- With `OPENROUTER_MODEL` set, the OpenRouter adapter uses that model value.
- The OpenRouter adapter maps a normal assistant text response into the existing `XMatrix.LLM.reply()` shape with a `message`, `proposals`, and `stage_status`.
- The OpenRouter adapter maps OpenAI-compatible function/tool calls named `propose_elements` into structured proposal maps with normalized element types.
- Existing proposal-card UI behaviour continues to work with structured proposals returned by the configured adapter.
- With no `OPENROUTER_API_KEY`, an AI-enabled draft uses the scripted guide and shows a useful fallback notice that does not mention Anthropic as the missing provider.
- If OpenRouter returns a non-2xx response, malformed response, or request error, the LiveView catches the adapter error, shows the existing friendly fallback flash, and continues with the scripted guide.
- Test configuration continues to pin `XMatrix.LLM.Scripted` unless a test explicitly overrides the adapter.
- Automated tests use fake/test adapters and do not make real OpenRouter network calls.
- Existing tests that currently set or assert `anthropic_api_key` are updated to OpenRouter-oriented configuration.
- `mix precommit` passes.

## Open Business Decisions

None known.

## Implementation Plan

1. Add `XMatrix.LLM.OpenRouter`.
   - Create `lib/x_matrix/llm/open_router.ex`.
   - Implement `@behaviour XMatrix.LLM`.
   - Use `Req.post/2` against `https://openrouter.ai/api/v1/chat/completions`.
   - Read `:openrouter_api_key` and `:openrouter_model` from application config.
   - Default the model to `openai/gpt-oss-120b:free`.
   - Send recent conversation messages in OpenAI-compatible `%{role, content}` format.
   - Include the same X-Matrix system prompt intent as the Anthropic adapter, including strategy “even over” guidance.

2. Define OpenRouter tool/function schema.
   - Use OpenAI-compatible `tools: [%{type: "function", function: ...}]`.
   - Function name: `propose_elements`.
   - Parameters should match the current proposal schema:
     - array of proposals;
     - each proposal has `type`, `title`, and optional `description`.
   - Keep the allowed element types aligned with current TASTE types: `true_north`, `aspiration`, `strategy`, `evidence`, `tactic`.

3. Parse OpenRouter responses.
   - Extract assistant text from `choices[0].message.content`.
   - Extract proposals from `choices[0].message.tool_calls[*].function.arguments` when the function name is `propose_elements`.
   - Decode JSON arguments safely.
   - Return `{:ok, %{message: ..., proposals: ..., stage_status: :continue}}`.
   - Return `{:error, reason}` for HTTP errors, missing expected fields, or invalid JSON that prevents safe parsing.

4. Update runtime configuration.
   - In `config/runtime.exs`, configure:
     - `openrouter_api_key: System.get_env("OPENROUTER_API_KEY")`;
     - `openrouter_model: System.get_env("OPENROUTER_MODEL", "openai/gpt-oss-120b:free")`.
   - Keep Anthropic config if useful for the inactive adapter, but do not make Anthropic the default active provider.

5. Update LiveView provider selection.
   - Replace `anthropic_key?`-based default activation with OpenRouter-aware logic.
   - For `ai_assisted: true`, use `Application.get_env(:x_matrix, :llm_adapter, XMatrix.LLM.OpenRouter)` only when an OpenRouter key is configured.
   - Otherwise use `XMatrix.LLM.Scripted`.
   - Update fallback notice text to mention OpenRouter or be provider-neutral.
   - Update `default_ai_assisted?/0` so new drafts default to AI-on only when an OpenRouter key is configured.

6. Update tests.
   - Replace `anthropic_api_key` setup in LiveView tests with `openrouter_api_key`.
   - Keep tests deterministic by overriding `:llm_adapter` with scripted or fake adapters.
   - Add unit tests for `XMatrix.LLM.OpenRouter` response parsing if the parsing functions are public enough for direct testing, or test through a small injectable/mockable HTTP seam if introduced during implementation.
   - Ensure no test depends on a real `OPENROUTER_API_KEY` or external network.

7. Add developer setup note.
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
