# Manual demo script: True North agreement flow

Use this after implementation to smoke-test the iteration locally.

## With OpenRouter configured

1. Ensure `.local/secrets.envrc` contains `OPENROUTER_API_KEY=...` and direnv has loaded it.
2. Start the app.
3. Visit `/interview` to create a new draft.
4. Confirm the first screen is a True North agreement flow.
5. Send a conversational answer, for example: "We want every family in our city to have a safe, stable home."
6. Confirm the message does not immediately save a True North element.
7. Ask for options if needed: "Give me three possible True North statements."
8. Confirm multiple candidate cards appear, each with a pithy statement and short explanation.
9. Give refinement feedback, for example: "Make them shorter and less consultant-y."
10. Confirm revised candidates appear and no matrix element has been saved yet.
11. Edit or accept one candidate and submit it.
12. Confirm the app immediately advances to Aspirations.
13. Navigate back to True North.
14. Confirm the conversation/candidates are restored.
15. Resubmit a changed True North and confirm there is still only one True North element.

## Without OpenRouter configured

1. Start the app with no `OPENROUTER_API_KEY`.
2. Start or open an AI-assisted draft.
3. Confirm the no-key/scripted fallback remains usable.
4. Confirm True North still requires explicit submission before anything is saved.
