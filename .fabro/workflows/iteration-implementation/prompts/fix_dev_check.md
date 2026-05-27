The preceding Run Dev Check stage failed while implementing {{ inputs.plan_path }}.

This is the automated-test feedback loop for the implementation. Use the dev check output and current working tree to fix the failures until the full automated suite can pass. Stay within the iteration scope.

Rules:

- Prefer the smallest correct fix.
- Do not skip or weaken tests, checks, Credo rules, formatter rules, or compiler warnings unless the plan explicitly says to change them.
- Never edit acceptance feature files (`*.feature`, including files under `acceptance-tests/`). Treat them as locked acceptance criteria; if they appear wrong, report the blocker instead of changing them.
- Do not add unrelated cleanup.
- Re-read relevant project guidance before touching Phoenix, LiveView, HEEx, Ecto, or Elixir test code.
- Do not commit changes.

When finished, summarize the fixes and which dev check failure each fix addresses.
