# Iteration Plan Review: 004-openrouter-llm-provider

**Decision:** NOT READY

**Confidence:** High

---

## Blocking Gaps

1. **Provider priority order is inconsistent across the plan**
   - AC #2 states: "OpenRouter (if key exists) → scripted fallback (if no key or error)"
   - Implementation step 3 states: "OpenRouter → Anthropic → scripted"
   - These contradict each other. What happens when BOTH `OPENROUTER_API_KEY` and `ANTHROPIC_API_KEY` are set?

2. **Anthropic's role is ambiguous**
   - AC #9 says Anthropic "remains in the codebase but inactive during this iteration"
   - AC #8 lists only "OpenRouter, scripted fallback" for settings display - no Anthropic
   - What does "inactive" mean? Never called? Still in selection logic but deprioritized? Available as manual override?

3. **Settings page specification conflicts with provider logic**
   - AC #8 says settings show "OpenRouter, scripted fallback" only
   - But implementation step 3 includes Anthropic in the selection logic
   - If Anthropic is in the selection logic, shouldn't it appear in settings?

4. **Provider selection integration point is vague**
   - Implementation step 3 says "Update `MyApp.Interviews.InterviewSession.ai_response/2` (or wherever provider is chosen)"
   - The phrase "or wherever" indicates uncertainty about a critical integration point
   - This should be known before implementation begins

5. **Stop condition doesn't cover all cases**
   - Stop condition says "app's active AI path uses OpenRouter successfully when configured"
   - Doesn't address what happens when both OpenRouter and Anthropic keys are configured
   - Doesn't define success criteria for the Anthropic path if it's still selectable

---

## Non-Blocking Improvements

1. **Specify test file names and locations** - would clarify where adapter tests, LiveView tests, and integration tests should go (e.g., `test/my_app/llm/openrouter_adapter_test.exs`)

2. **Name the settings template file** - implementation step 5 should specify which template to update (likely `lib/my_app_web/live/settings_live.ex` and `.html.heex`)

3. **Define error handling specifics** - timeout values, retry strategy, connection pool settings for HTTP requests to OpenRouter

4. **Specify logging strategy** - what gets logged (provider selection decisions, API errors, fallback events) and at what level

5. **Make non-goals explicit** - add a "Non-Goals" section stating: no data migration, no provider configuration UI, no removal of Anthropic, no changes to existing interviews

6. **Document the model selection override** - clarify how `OPENROUTER_MODEL` env var overrides the default, including validation/error handling for invalid model names

7. **Clarify "clear notice" copy** - AC #5 mentions "clear notice" when falling back - specify the exact message or defer to implementation

---

## Smallest Viable Iteration

**Recommended slice:** Add OpenRouter as the **only** active LLM provider for this iteration.

**Rationale:** This eliminates all ambiguity about provider priority and reduces implementation complexity while still achieving the stated goal (Matt can test without Anthropic credits).

**Scope:**
- Add OpenRouter adapter supporting chat + tool calls
- Provider selection: OpenRouter (if key) → scripted (if no key)
- Temporarily disable/bypass Anthropic adapter (comment out or skip in selection)
- Settings shows "OpenRouter" or "Scripted Fallback"
- Tests and documentation
- Follow-up iteration can re-enable multi-provider support with proper priority rules

**What's deferred:**
- Multi-provider priority logic
- Handling both keys simultaneously
- Anthropic adapter remaining active

This makes the iteration smaller, eliminates the blocking ambiguities, and still delivers the core value: Matt can test with OpenRouter's free tier.

---

## Required Plan Edits

### 1. Resolve provider priority (choose one approach)

**Option A - OpenRouter Only (recommended for this iteration):**
```markdown
## Acceptance Criteria (edited)

2. Provider priority order is: OpenRouter (if `OPENROUTER_API_KEY` exists) → scripted fallback (if no key or error). Anthropic adapter is bypassed for this iteration.

8. Settings page shows which provider is currently active: "OpenRouter" or "Scripted Fallback".

9. ~~No changes to existing Anthropic adapter (it remains in the codebase but inactive during this iteration).~~
   Anthropic adapter is temporarily bypassed in provider selection for this iteration. A follow-up iteration will implement proper multi-provider support.
```

**Option B - Multi-Provider (requires more detailed specification):**
```markdown
## Acceptance Criteria (edited)

2. Provider priority order is: 
   - If `OPENROUTER_API_KEY` exists → OpenRouterAdapter
   - Else if `ANTHROPIC_API_KEY` exists → AnthropicAdapter  
   - Else → Scripted fallback
   If a selected provider returns an error, fall back to scripted (do not cascade to next provider).

8. Settings page shows which provider is currently active: "OpenRouter", "Anthropic (Claude)", or "Scripted Fallback".

9. No changes to existing Anthropic adapter implementation. Provider selection logic changes to check OpenRouter first.
```

### 2. Specify provider selection location

```markdown
## Implementation Steps (step 3, edited)

3. Implement provider selection logic in `MyApp.Interviews.InterviewSession.determine_llm_provider/0` (or extract to new `MyApp.LLM.ProviderSelector` module if needed):
   - [Continue with priority logic based on Option A or B above]
   - Update `ai_response/2` to call the provider selection logic
```

### 3. Update settings specification

```markdown
## Implementation Steps (step 5, edited)

5. Update settings to show active provider:
   - Update `lib/my_app_web/live/settings_live.ex` and `settings_live.html.heex`
   - Add `determine_active_provider/0` function that checks env vars and returns provider name
   - Display result in settings UI with appropriate icon/styling
   - [For Option B: Show all three possibilities: OpenRouter, Anthropic, Scripted]
```

### 4. Clarify stop condition

```markdown
## Validation Plan (stop condition, edited)

Stop condition:

- [Option A] When `OPENROUTER_API_KEY` is set, the app uses OpenRouter successfully. When unset, app uses scripted fallback. Settings correctly displays active provider. `mix precommit` passes.

- [Option B] For any combination of API keys (both set, only OpenRouter, only Anthropic, neither), the app selects the correct provider per priority order, receives responses or falls back appropriately, and settings displays the active provider. `mix precommit` passes.
```

---

## Validation Plan

To prove the iteration succeeded:

### Automated Validation
1. **Adapter tests** (`test/my_app/llm/openrouter_adapter_test.exs`):
   - Mock HTTP responses for chat completion
   - Mock HTTP responses for tool call (`propose_elements`)
   - Test error handling (network errors, API errors, malformed responses)
   - Verify correct request headers (Authorization, HTTP-Referer, etc.)

2. **Provider selection tests** (in `InterviewSession` test or dedicated provider selector test):
   - With `OPENROUTER_API_KEY` set → selects OpenRouter
   - Without key → selects scripted fallback
   - [Option B only] With both keys → selects OpenRouter
   - [Option B only] With only `ANTHROPIC_API_KEY` → selects Anthropic

3. **LiveView tests** (`test/my_app_web/live/interview_live_test.exs`):
   - Start interview with OpenRouter configured (using test stub/mock)
   - Verify AI responses appear
   - Verify proposal cards display when tool calls trigger
   - Test without key → verify scripted path with notice

4. **Settings display test** (`test/my_app_web/live/settings_live_test.exs`):
   - With key → displays "OpenRouter"
   - Without key → displays "Scripted Fallback"
   - [Option B only] With Anthropic key → displays "Anthropic (Claude)"

5. **Precommit:** `mix precommit` passes (all tests, format, credo)

### Manual Validation
1. Configure `.local/secrets.envrc` with `OPENROUTER_API_KEY=sk-or-v1-...`
2. Reload direnv: `direnv allow`
3. Start dev server: `mix phx.server`
4. Navigate to settings → verify "OpenRouter" displays as active provider
5. Start new interview with AI enabled
6. Send chat message → verify AI response from OpenRouter appears
7. Send message that should trigger tool call (e.g., "I propose we focus on X") → verify proposal card displays
8. Unset key: `unset OPENROUTER_API_KEY`
9. Restart server → verify settings shows "Scripted Fallback"
10. Start new interview → verify scripted path with notice about no provider

### Success Criteria
- All automated tests pass
- Manual flow works with OpenRouter key
- Manual flow works without key (scripted fallback)
- Settings accurately reflects active provider
- No regressions in existing interview flows
- `mix precommit` clean

---

## Summary

The plan has a strong foundation with clear goal, good validation strategy, and reasonable scope. However, **critical ambiguities around provider priority** prevent implementation from starting. The core issue is inconsistency between acceptance criteria and implementation steps regarding Anthropic's role.

**Recommended path forward:** Edit the plan to use **Option A** (OpenRouter-only for this iteration), which achieves the goal with minimal complexity and no ambiguity. A follow-up iteration can add proper multi-provider support with explicit priority rules and configuration.