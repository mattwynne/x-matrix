Apply the automatic repair brief from the preceding Synthesize Review stage for {{ inputs.plan_path }}.

Rules:

- Fix only the concrete blocking issues identified by the reviewers.
- Treat this as a post-green refactoring/maintainability pass. Do not add new product behaviour here.
- Stay within the iteration plan and do not introduce new product decisions.
- Never edit acceptance feature files (`*.feature`, including files under `acceptance-tests/`). If a requested fix requires changing one, stop and report that it needs human input.
- Add or update automated tests only when needed to preserve or clarify existing behaviour while refactoring.
- Do not skip or weaken existing validation.
- Do not commit changes.

When finished, summarize each review issue and how you addressed it.
