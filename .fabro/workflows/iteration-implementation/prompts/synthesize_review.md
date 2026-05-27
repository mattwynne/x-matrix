Synthesize the independent implementation reviews for {{ inputs.plan_path }}.

Decide whether the implementation is acceptable now, can be repaired automatically, or needs human input.

Use these standards:

- Accept only if the implementation satisfies the plan, avoids out-of-scope work, and dev check passed.
- Treat automated tests/dev check as the behavioural feedback loop. Review-stage automatic fixes should be refactoring/maintainability/convention fixes after the suite is green, not new feature work.
- Request automatic fixes only for concrete, bounded refactoring, maintainability, project-convention, or low-risk test-quality issues that an agent can resolve without changing product behaviour or feature files.
- Do not request edits to acceptance feature files (`*.feature`). If reviewers believe feature files or acceptance criteria are wrong, route to human input.
- Require human input for unresolved business decisions, ambiguous acceptance criteria, behavioural gaps, missing acceptance coverage that cannot be fixed safely as a test-only improvement, architectural choices outside the plan, or repeated/large failures.

Return a concise Markdown synthesis with:

- Decision: ACCEPTED, FIX, or HUMAN_INPUT
- Blocking issues, grouped by severity
- Exact repair brief if automatic fixes are appropriate
- Manual follow-ups, if any

End your response with exactly one JSON object that Fabro can use for routing:

If accepted:
{"context_updates":{"implementation_accepted":true,"review_fixes_available":false}}

If automatic fixes are appropriate:
{"context_updates":{"implementation_accepted":false,"review_fixes_available":true}}

If human input is required:
{"context_updates":{"implementation_accepted":false,"review_fixes_available":false}}
