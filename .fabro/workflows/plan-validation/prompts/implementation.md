You are validating an iteration plan before implementation.

Use the plan text from the preceding `Read Iteration Plan` stage.

Assess the implementation plan and unresolved technical decisions. Judge whether an engineer could start confidently without inventing architecture, data model, UX flow, or integration behaviour mid-implementation.

Check:

1. Are implementation steps clear, ordered, and specific?
2. Are likely files, modules, migrations, tests, and interfaces named where useful?
3. Are data model, API, UI, workflow, integration, and background-job changes clear enough?
4. Are testing and validation steps included at the right level?
5. Are any technical decisions still unresolved or hidden behind vague wording?
6. Does the plan respect this repository's known conventions where applicable?

Return a concise Markdown report with:

- Verdict: PASS, WARN, or FAIL
- Clear steps: what is implementation-ready
- Ambiguities: vague or missing technical detail
- Open technical decisions: decisions required before implementation
- Risks: sequencing, migration, data, testing, or integration risks
- Suggested implementation-plan edits: concrete additions or rewrites
