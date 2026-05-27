You are validating an iteration plan before implementation.

Use the plan text from the preceding `Read Iteration Plan` stage.

Assess acceptance criteria and unresolved business decisions.

Check:

1. Are acceptance criteria concrete, clear, complete, and testable?
2. Do they cover happy paths, important edge cases, permissions, error states, and data/state changes where relevant?
3. Can a reviewer use them to decide objectively whether the work is done?
4. Are user-visible behaviours specified precisely enough?
5. Are any product, policy, copy, workflow, or domain decisions still unresolved?

Return a concise Markdown report with:

- Verdict: PASS, WARN, or FAIL
- Strong criteria: criteria that are already objective and useful
- Weak or missing criteria: exact improvements needed
- Missing scenarios: behaviours or edge cases not covered
- Open business decisions: decisions that must be made before implementation
- Suggested acceptance criteria: concrete criteria to add or rewrite
