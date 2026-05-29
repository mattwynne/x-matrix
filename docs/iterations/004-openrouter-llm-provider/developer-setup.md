# Developer setup: OpenRouter

This iteration switches the active AI provider to OpenRouter.

Local environment variables:

```sh
OPENROUTER_API_KEY=your-key-here
# Optional; defaults to the free model below.
OPENROUTER_MODEL=openai/gpt-oss-120b:free
```

In this repo, local secrets should live in `.local/secrets.envrc`, which is loaded by direnv and ignored by git.

If `OPENROUTER_API_KEY` is missing or blank, the interview should use the scripted guide fallback. Tests should not require a real OpenRouter key or make network calls.

A local spike on 2026-05-28 confirmed that `openai/gpt-oss-120b:free` returned `usage.cost: 0`, supported JSON responses, and supported OpenAI-compatible function/tool calls for structured proposals.
