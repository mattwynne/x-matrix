You are validating an iteration plan before implementation.

Use the plan text from the preceding `Read Iteration Plan` stage.

Assess only scope focus. Be skeptical about over-large iterations.

Check:

1. Is the scope focused on one coherent outcome?
2. Could this plan be sliced smaller while still delivering a useful increment?
3. Are any tasks nice-to-have, speculative, or unrelated to the core outcome?
4. Are explicit non-goals or out-of-scope boundaries stated?
5. Are dependencies on future work or external systems clear?

Return a concise Markdown report with:

- Verdict: PASS, WARN, or FAIL
- Core slice: the smallest useful version you can identify
- Scope risks: items that may make the iteration too large
- Suggested cuts: work to defer, if any
- Questions: scope decisions that must be made before implementation
