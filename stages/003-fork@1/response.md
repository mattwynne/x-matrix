# Iteration Plan Review: True North Agreement Flow

## Decision: NOT READY

## Confidence: High

The plan has a clear goal, good scope boundaries, and a solid validation approach, but contains **blocking technical gaps** that would force implementation to make critical design decisions ad-hoc.

---

## Blocking Gaps

1. **Agent tool call schema undefined**
   - Plan mentions "Add candidate-proposal tool schema" but doesn't specify the structure
   - Critical: developers cannot implement agent integration without knowing the exact JSON format for tool calls and responses
   - Missing: What fields? What's the structure for multiple candidates? How are they identified?

2. **Session state structure unspecified**
   - The `state` JSONB column structure isn't defined
   - Developers need to know: What fields? How are candidates stored? How is conversation history structured?
   - Impacts persistence, restoration, and candidate ID management

3. **Candidate ID generation strategy unclear**
   - Plan identifies this as a risk ("Restoring old candidate IDs from JSONB needs care") but doesn't resolve it
   - Blocking: LiveView events require stable IDs; unclear if IDs are UUIDs, sequential, or derived
   - Impacts both initial display and session restoration

4. **Agent integration details too vague**
   - Step 6 says "Wire facilitator agent and enable True North mode" but doesn't specify:
     - What data is passed to the agent?
     - What response format is expected?
     - How does the agent know when to propose candidates vs. continue conversation?
     - What's the prompt for True North mode?

5. **Missing critical edge case acceptance criteria**
   - What happens if agent proposes 0 candidates? Malformed candidates?
   - Can user submit without accepting/editing a candidate? (likely should be blocked)
   - Are there permission checks? (only strategy owner should participate)
   - Can user abandon conversation and start fresh?

---

## Non-Blocking Improvements

1. Could specify whether session auto-saves on each turn or only on explicit actions
2. Could name specific test files that will be created (`true_north_agreement_live_test.exs`, etc.)
3. Could clarify maximum conversation turns or timeout behavior (or explicitly defer)
4. Could reference UI copy/prompt text or note it's deferred to implementation
5. Could specify whether the `description` field on True North is required or optional

---

## Smallest Viable Iteration

The current plan is already focused, but could be smaller:

**Ultra-minimal (complete in one session only):**
1. True North agreement UI with conversation loop
2. Agent proposes candidates (min 1, max 5)
3. User accepts/edits one candidate
4. Submit creates True North and advances to Aspirations
5. **No session persistence** (must complete in one session)
6. **No resubmission** (covered by separate future iteration)

This removes ~40% of complexity while still delivering the core "explicit agreement" value.

**Recommended approach:** Keep current scope but resolve blocking gaps. The plan as written is appropriately sized if technical decisions are documented.

---

## Required Plan Edits

### 1. Add "Appendix: Agent Integration" section

```markdown
## Appendix: Agent Integration

### Tool Call Schema

The facilitator agent will have a `propose_true_north_candidates` tool:

```json
{
  "name": "propose_true_north_candidates",
  "description": "Propose one or more candidate True North statements based on the conversation",
  "parameters": {
    "type": "object",
    "properties": {
      "candidates": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "title": {"type": "string"},
            "description": {"type": "string"}
          },
          "required": ["title", "description"]
        },
        "minItems": 1,
        "maxItems": 5
      }
    },
    "required": ["candidates"]
  }
}
```

### True North Prompt Mode

The facilitator will receive a system message specifying True North mode:
- Current section: "true_north"
- Task: Help user articulate their True North through conversation
- When ready: Use `propose_true_north_candidates` tool to offer specific options
```

### 2. Add "Appendix: Session State Structure" section

```markdown
## Appendix: Session State Structure

The `strategy_section_sessions.state` JSONB column structure:

```json
{
  "conversation": [
    {"role": "assistant", "content": "...", "timestamp": "2025-01-15T10:00:00Z"},
    {"role": "user", "content": "...", "timestamp": "2025-01-15T10:01:00Z"}
  ],
  "candidates": [
    {
      "id": "uuid-here",
      "title": "...",
      "description": "...",
      "status": "proposed|edited|accepted"
    }
  ],
  "submitted_candidate_id": "uuid-here-or-null"
}
```

Candidate IDs: UUIDs generated when agent proposes or user edits. Preserved across sessions to keep LiveView event targets stable.
```

### 3. Expand Acceptance Criteria

Add these to the existing list:

```markdown
10. If the agent proposes zero or malformed candidates, the conversation can continue and fallback UI allows manual entry.
11. User cannot submit until accepting or editing at least one candidate; submit button is disabled otherwise.
12. Only the strategy owner can participate in the True North agreement; other users see read-only view.
13. User can restart the True North conversation from scratch if desired (confirmation required).
```

### 4. Clarify Implementation Steps

Revise step 6:

```markdown
6. Wire facilitator agent:
   - Pass current conversation history and section="true_north" context
   - Register `propose_true_north_candidates` tool with agent
   - Handle tool call responses to create candidate records with UUIDs
   - Append agent messages to conversation in session state
```

Add new step after 12:

```markdown
12a. Define True North mode prompt template in `lib/app/strategy_facilitator/prompts.ex`:
   - System message explaining True North focus
   - Instructions for when to propose candidates
   - Example conversation flow
```

### 5. Resolve "Open Technical Decisions" section

Replace "None known" with:

```markdown
## Open Technical Decisions

All resolved:

1. **Candidate IDs**: UUIDs generated server-side, stored in session state, preserved across resume
2. **Session state structure**: Documented in Appendix
3. **Tool call schema**: Documented in Appendix
4. **Minimum/maximum candidates**: 1-5 per proposal (can be adjusted based on feedback)
5. **Conversation turn limits**: None initially; can add timeout/turn-limit later if needed
```

---

## Validation Plan

After the blocking gaps are resolved:

### Automated Validation
1. **Unit tests** verify:
   - Session state serialization/deserialization
   - Candidate ID generation is stable
   - Tool call parsing handles valid/invalid responses

2. **LiveView tests** verify:
   - All 13 acceptance criteria (expanded list)
   - Candidate display uses stable IDs
   - Session restoration preserves candidates and conversation
   - Submit button disabled when no candidate accepted/edited
   - Permission checks work

3. **Integration tests** verify:
   - Agent receives correct context
   - Tool call responses create candidates correctly
   - Fallback mode works without real agent

4. **Run `mix precommit`** and ensure all checks pass

### Manual Validation
1. Follow the 11-step manual validation plan from the original plan
2. Add these additional checks:
   - Verify submit button is disabled until candidate accepted/edited
   - Verify non-owner cannot participate
   - Verify restart conversation works
   - Test with agent proposing 1, 3, and 5 candidates
   - Test with agent proposing malformed JSON (should fallback gracefully)

### Success Criteria
- All automated tests pass
- Manual validation completes without bugs
- `manual-demo-script.md` can be followed successfully
- Matt can complete a True North agreement end-to-end without errors or confusion

---

## Recommendation

**Block implementation until plan is revised.** The gaps are addressable but critical. Once the author:
1. Documents the tool call schema
2. Specifies the session state structure  
3. Defines the candidate ID strategy
4. Expands acceptance criteria for edge cases
5. Clarifies agent integration details

...the plan will be **READY** with **High confidence**.

The core architecture (session table, LiveView structure, advancement flow) is sound. The missing pieces are implementation contracts that must be decided before coding begins.