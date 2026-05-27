You are validating an iteration plan before implementation.

Use the plan text from the preceding `Read Iteration Plan` stage.

Assess whether the plan makes the expected post-iteration capability and success validation explicit.

Check:

1. What should we be able to do after this iteration that we cannot do now?
2. Is that capability stated in user/business terms?
3. Is there a concrete demo, test, manual check, metric, or observable signal that proves success?
4. Are validation responsibilities clear: automated tests, acceptance tests, manual QA, stakeholder review, or production checks?
5. Would someone know when to stop working?

Return a concise Markdown report with:

- Verdict: PASS, WARN, or FAIL
- New capability: the before/after capability delta
- Success validation: how success will be proven
- Missing validation: checks or evidence still needed
- Stop condition: the clearest definition of done you can infer
- Suggested edits: concrete language to add to the plan
