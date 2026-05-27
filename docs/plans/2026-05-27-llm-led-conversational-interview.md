# LLM-led Conversational Interview Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current form-like interview with a chat-led TASTE interview that works for free with a scripted facilitator and can optionally use Anthropic to propose strategy elements, while preserving explicit user confirmation before anything is saved.

**Architecture:** Keep the existing `Strategies` context and read-only matrix route as the source of truth for confirmed items and correlations. Add transcript persistence, an adapter-based `XMatrix.LLM` boundary, and a chat-oriented `InterviewLive` state machine for element stages, then hand off to the existing relationship rating screens and review. Build scripted mode first so all tests and `dev check` pass without API keys; add Anthropic last behind the same behaviour.

**Tech Stack:** Phoenix LiveView 1.1, Ecto, PostgreSQL, `phoenix_test`, Req for Anthropic HTTP calls, Tailwind CSS classes in HEEx.

---

## Current baseline

- Current interview route: `lib/x_matrix_web/router.ex` routes `/interview` and `/interview/:id` to `XMatrixWeb.InterviewLive`.
- Current interview implementation: `lib/x_matrix_web/live/interview_live.ex` is a one-question-at-a-time LiveView with element and correlation steps.
- Current write-side context: `lib/x_matrix/strategies.ex` has draft creation, element mutation, correlation mutation, current-step updates, resume, and completion.
- Current schema: `lib/x_matrix/strategies/strategy.ex` has `status` and `current_step`; no transcript or AI toggle yet.
- Existing tests to preserve or rewrite carefully:
  - `test/x_matrix_web/live/interview_live_test.exs`
  - `test/x_matrix_web/live/interview_flow_test.exs`
  - `test/x_matrix/strategies_test.exs`

## Stage names

Use these persisted `strategies.current_step` values for the new element flow:

- `chat:true_north`
- `chat:aspiration`
- `chat:strategy`
- `chat:evidence`
- `chat:tactic`
- Existing correlation steps may remain as `corr:intro:*` and `corr:src:*`.
- Existing review may remain `review`.

The old `welcome`, `name`, `tn_statement`, `tn_why`, and `elem:*` steps may be migrated in code by `sanitize_step/2` to the closest new chat step rather than requiring a database migration.

---

### Task 1: Add transcript and AI toggle schema

**Files:**
- Create migration with `mix ecto.gen.migration add_chat_interview_state`
- Modify: generated migration in `priv/repo/migrations/*_add_chat_interview_state.exs`
- Modify: `lib/x_matrix/strategies/strategy.ex`
- Create: `lib/x_matrix/strategies/strategy_message.ex`
- Modify: `lib/x_matrix/strategies.ex`
- Test: `test/x_matrix/strategies_test.exs`

**Step 1: Write failing context tests**

Add tests covering:

```elixir
test "create_draft_strategy/1 stores ai_assisted" do
  {:ok, strategy} = Strategies.create_draft_strategy(%{title: "AI draft", ai_assisted: true})
  assert strategy.ai_assisted == true
end

test "messages can be appended and listed in order", %{strategy: strategy} do
  {:ok, first} = Strategies.add_message(strategy, :assistant, "What is your True North?")
  {:ok, second} = Strategies.add_message(strategy, :user, "Everyone has a safe home")

  assert [^first, ^second] = Strategies.list_messages(strategy)
end
```

**Step 2: Run tests to verify failure**

Run:

```bash
mix test test/x_matrix/strategies_test.exs
```

Expected: FAIL because `ai_assisted`, `StrategyMessage`, `add_message/3`, and `list_messages/1` do not exist.

**Step 3: Generate and implement migration**

Run:

```bash
mix ecto.gen.migration add_chat_interview_state
```

Implement:

```elixir
defmodule XMatrix.Repo.Migrations.AddChatInterviewState do
  use Ecto.Migration

  def change do
    alter table(:strategies) do
      add :ai_assisted, :boolean, null: false, default: false
    end

    create table(:strategy_messages) do
      add :strategy_id, references(:strategies, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:strategy_messages, [:strategy_id, :inserted_at, :id])
  end
end
```

**Step 4: Implement schema changes**

In `lib/x_matrix/strategies/strategy.ex` add:

```elixir
field :ai_assisted, :boolean, default: false
has_many :messages, XMatrix.Strategies.StrategyMessage
```

Include `:ai_assisted` in `cast/3`.

Create `lib/x_matrix/strategies/strategy_message.ex`:

```elixir
defmodule XMatrix.Strategies.StrategyMessage do
  use Ecto.Schema
  import Ecto.Changeset

  alias XMatrix.Strategies.Strategy

  schema "strategy_messages" do
    field :role, Ecto.Enum, values: [:assistant, :user]
    field :content, :string

    belongs_to :strategy, Strategy

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:strategy_id, :role, :content])
    |> validate_required([:strategy_id, :role, :content])
  end
end
```

**Step 5: Implement context functions**

In `lib/x_matrix/strategies.ex` alias `StrategyMessage` and add:

```elixir
def add_message(%Strategy{} = strategy, role, content) when role in [:assistant, :user] do
  %StrategyMessage{}
  |> StrategyMessage.changeset(%{strategy_id: strategy.id, role: role, content: content})
  |> Repo.insert()
end

def list_messages(%Strategy{} = strategy) do
  StrategyMessage
  |> where([m], m.strategy_id == ^strategy.id)
  |> order_by([m], asc: m.inserted_at, asc: m.id)
  |> Repo.all()
end
```

**Step 6: Run tests to verify pass**

Run:

```bash
mix test test/x_matrix/strategies_test.exs
```

Expected: PASS.

**Step 7: Commit**

```bash
git add priv/repo/migrations lib/x_matrix/strategies test/x_matrix/strategies_test.exs
git commit -m "feat: persist interview transcript"
```

---

### Task 2: Add the LLM behaviour and scripted adapter

**Files:**
- Create: `lib/x_matrix/llm.ex`
- Create: `lib/x_matrix/llm/scripted.ex`
- Modify: `config/test.exs`
- Test: `test/x_matrix/llm/scripted_test.exs`

**Step 1: Write failing adapter tests**

Create tests asserting:

```elixir
assert {:ok, reply} = XMatrix.LLM.Scripted.facilitate(:true_north, [], %{})
assert reply.message =~ "True North"
assert reply.proposals == []
assert reply.stage_status in [:continue, :ready_to_advance]
```

Also test each stage atom: `:aspiration`, `:strategy`, `:evidence`, `:tactic`.

**Step 2: Run tests to verify failure**

```bash
mix test test/x_matrix/llm/scripted_test.exs
```

Expected: FAIL because modules do not exist.

**Step 3: Implement `XMatrix.LLM` behaviour**

`lib/x_matrix/llm.ex`:

```elixir
defmodule XMatrix.LLM do
  @type message :: %{role: :assistant | :user, content: String.t()}
  @type proposal :: %{type: atom(), title: String.t(), description: String.t() | nil}
  @type reply :: %{
          message: String.t(),
          proposals: [proposal()],
          stage_status: :continue | :ready_to_advance
        }

  @callback facilitate(stage :: atom(), conversation :: [message()], snapshot :: map()) ::
              {:ok, reply()} | {:error, term()}
end
```

**Step 4: Implement `XMatrix.LLM.Scripted`**

Return deterministic questions, no proposals. Include strategy guidance with the phrase `even over`.

**Step 5: Configure tests to use scripted adapter**

In `config/test.exs` add:

```elixir
config :x_matrix, :llm_adapter, XMatrix.LLM.Scripted
```

**Step 6: Run tests to verify pass**

```bash
mix test test/x_matrix/llm/scripted_test.exs
```

Expected: PASS.

**Step 7: Commit**

```bash
git add lib/x_matrix/llm.ex lib/x_matrix/llm/scripted.ex config/test.exs test/x_matrix/llm/scripted_test.exs
git commit -m "feat: add scripted interview facilitator"
```

---

### Task 3: Add draft-only mutation guards

**Files:**
- Modify: `lib/x_matrix/strategies.ex`
- Test: `test/x_matrix/strategies_test.exs`

**Step 1: Write failing tests**

Add tests that complete a strategy, then assert these return errors and do not mutate data:

- `update_strategy/2`
- `set_step/2`
- `add_element/2`
- `update_element/2`
- `delete_element/1`
- `upsert_correlation/4`
- `add_message/3`

Use assertions like:

```elixir
assert {:error, :strategy_complete} = Strategies.add_element(done, %{element_type: :tactic, title: "Nope"})
```

For element-specific functions, reload the element's strategy before deciding.

**Step 2: Run tests to verify failure**

```bash
mix test test/x_matrix/strategies_test.exs
```

Expected: FAIL because complete strategies can currently be mutated.

**Step 3: Implement minimal guards**

Add helpers:

```elixir
defp draft?(%Strategy{status: :draft}), do: true
defp draft?(_), do: false

defp reject_complete(%Strategy{} = strategy) do
  if draft?(strategy), do: :ok, else: {:error, :strategy_complete}
end
```

Call this in mutation functions. For element/correlation mutations, look up the owning strategy before mutating.

**Step 4: Run tests to verify pass**

```bash
mix test test/x_matrix/strategies_test.exs
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/x_matrix/strategies.ex test/x_matrix/strategies_test.exs
git commit -m "fix: prevent completed strategy mutations"
```

---

### Task 4: Build chat layout in `InterviewLive` using scripted mode only

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Test: `test/x_matrix_web/live/interview_live_test.exs`

**Step 1: Replace old welcome/name tests with chat UI tests**

Add tests asserting `/interview/:id` shows:

- transcript region with id `interview-transcript`
- form with id `chat-form`
- emerging matrix panel with id `emerging-matrix`
- progress nav with id `taste-progress`
- AI toggle with id `ai-toggle`

Example:

```elixir
conn
|> visit("/interview/#{strategy.id}")
|> assert_has("#interview-transcript")
|> assert_has("#chat-form")
|> assert_has("#emerging-matrix")
|> assert_has("#taste-progress")
```

**Step 2: Run tests to verify failure**

```bash
mix test test/x_matrix_web/live/interview_live_test.exs
```

Expected: FAIL because the old one-question UI is rendered.

**Step 3: Implement chat shell**

In `InterviewLive`:

- Keep current route handling.
- On `/interview`, create a draft with `current_step: "chat:true_north"` and navigate to `/interview/:id`.
- On load, assign:
  - `:messages` from `Strategies.list_messages/1`
  - `:stage` from `current_step`
  - confirmed elements grouped by type
  - `:ai_assisted` from strategy
  - `:pending_proposals` as `[]`
- Render a two-column layout with transcript left, emerging matrix right.
- Use `<Layouts.app flash={@flash}>` as the root wrapper.
- Add explicit DOM IDs listed in tests.
- If a draft has no transcript, add or display the scripted facilitator's first assistant prompt for the current stage.

**Step 4: Run tests to verify pass**

```bash
mix test test/x_matrix_web/live/interview_live_test.exs
```

Expected: PASS for the new chat shell tests; old incompatible tests should be rewritten, not kept.

**Step 5: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex test/x_matrix_web/live/interview_live_test.exs
git commit -m "feat: render chat interview shell"
```

---

### Task 5: Scripted mode direct entry

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Test: `test/x_matrix_web/live/interview_live_test.exs`

**Step 1: Write failing tests**

Test with `ai_assisted: false`:

```elixir
{:ok, strategy} = Strategies.create_draft_strategy(%{title: "S", current_step: "chat:aspiration", ai_assisted: false})

conn
|> visit("/interview/#{strategy.id}")
|> fill_in("Your answer", with: "Reduce rough sleeping")
|> click_button("Send")
|> assert_has("#emerging-matrix", text: "Reduce rough sleeping")
```

Then assert the database has an `:aspiration` element and both user and assistant messages.

**Step 2: Run tests to verify failure**

```bash
mix test test/x_matrix_web/live/interview_live_test.exs
```

Expected: FAIL because submit does not exist.

**Step 3: Implement `submit_message` event**

For AI OFF/scripted mode:

- Persist user message.
- Persist element for current stage with `Strategies.add_element/2`.
- Call `XMatrix.LLM.Scripted.facilitate/3` for the next assistant prompt and persist it.
- Reload confirmed elements and transcript.

For `chat:true_north`, add or update a single `:true_north` element instead of appending multiples.

**Step 4: Run tests to verify pass**

```bash
mix test test/x_matrix_web/live/interview_live_test.exs
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex test/x_matrix_web/live/interview_live_test.exs
git commit -m "feat: add scripted chat entry"
```

---

### Task 6: AI mode free text is chat-only plus Add my answer

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Test: `test/x_matrix_web/live/interview_live_test.exs`

**Step 1: Write failing tests**

With `ai_assisted: true` and scripted adapter configured in test:

- Submit `"Reduce rough sleeping"`.
- Assert it appears in transcript.
- Assert it does **not** appear in the emerging matrix yet.
- Click `Add my answer` on the user message.
- Assert it appears in the emerging matrix and is persisted as the current stage's element type.

Use a stable selector like `button[data-add-message-id]` or text `Add my answer` scoped to the message card.

**Step 2: Run tests to verify failure**

```bash
mix test test/x_matrix_web/live/interview_live_test.exs
```

Expected: FAIL because AI-mode semantics are not implemented.

**Step 3: Implement AI-mode submit semantics**

In `submit_message`:

- Always persist the user message.
- If `ai_assisted` is true, do not add an element directly.
- Call the configured adapter and persist assistant message.
- Render `Add my answer` for eligible user messages in element stages.

Add event `add_message_as_element` that loads the message and persists its content as a confirmed element.

**Step 4: Run tests to verify pass**

```bash
mix test test/x_matrix_web/live/interview_live_test.exs
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex test/x_matrix_web/live/interview_live_test.exs
git commit -m "feat: require confirmation for AI chat answers"
```

---

### Task 7: Proposal cards with Add, Dismiss, and Edit

**Files:**
- Create: `test/support/llm/proposing_adapter.ex`
- Modify: `test/support/conn_case.ex` if test config needs per-test adapter setup helpers
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Test: `test/x_matrix_web/live/interview_proposal_test.exs`

**Step 1: Create test adapter**

Create a deterministic adapter returning one proposal:

```elixir
defmodule XMatrix.TestLLM.ProposingAdapter do
  @behaviour XMatrix.LLM

  def facilitate(stage, _conversation, _snapshot) do
    {:ok,
     %{
       message: "I have a suggestion.",
       proposals: [%{type: stage, title: "Suggested item", description: "Suggested why"}],
       stage_status: :continue
     }}
  end
end
```

**Step 2: Write failing proposal tests**

Tests:

- Proposal card appears after a user message.
- Clicking Add persists it and updates `#emerging-matrix`.
- Clicking Dismiss removes it and does not persist it.
- Clicking Edit reveals a form; changing title then saving persists changed text.

**Step 3: Run tests to verify failure**

```bash
mix test test/x_matrix_web/live/interview_proposal_test.exs
```

Expected: FAIL because proposal cards do not exist.

**Step 4: Implement pending proposals**

Keep proposal cards transient in socket assigns:

```elixir
%{id: Ecto.UUID.generate(), type: stage, title: title, description: description}
```

Add events:

- `add_proposal`
- `dismiss_proposal`
- `edit_proposal`
- `save_proposal_edit`

Never persist proposals until Add/save-edit.

**Step 5: Run tests to verify pass**

```bash
mix test test/x_matrix_web/live/interview_proposal_test.exs
```

Expected: PASS.

**Step 6: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex test/support test/x_matrix_web/live/interview_proposal_test.exs
git commit -m "feat: confirm LLM element proposals"
```

---

### Task 8: Progress indicator and stage advancement

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Test: `test/x_matrix_web/live/interview_flow_test.exs`

**Step 1: Write failing tests**

Cover:

- TASTE progress shows True North, Aspirations, Strategies, Evidence, Tactics, Relationships, Review.
- `Move on` changes from `chat:true_north` to `chat:aspiration`.
- Adapter `stage_status: :ready_to_advance` does not advance unless `Move on` is clicked.
- Order is enforced: direct visits with future steps are sanitized only when invalid; UI never skips from elements to tactics before evidence.

**Step 2: Run tests to verify failure**

```bash
mix test test/x_matrix_web/live/interview_flow_test.exs
```

Expected: FAIL for the new progress semantics.

**Step 3: Implement stage machine**

Add a stage list:

```elixir
@element_stages [:true_north, :aspiration, :strategy, :evidence, :tactic]
```

Map stages to current_step strings and element types. Add `move_on` event that calls `Strategies.set_step/2` with the next stage. After `chat:tactic`, move to existing `corr:intro:strategy_aspiration`.

**Step 4: Run tests to verify pass**

```bash
mix test test/x_matrix_web/live/interview_flow_test.exs
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex test/x_matrix_web/live/interview_flow_test.exs
git commit -m "feat: add TASTE chat stage progression"
```

---

### Task 9: Preserve relationship rating screens and finish flow

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Test: `test/x_matrix_web/live/interview_flow_test.exs`
- Test: `test/x_matrix_web/live/interview_live_test.exs`

**Step 1: Write failing end-to-end test**

Rewrite the existing end-to-end flow to:

- Start `/interview`.
- Use scripted chat to add True North, aspiration, strategy, evidence, tactic.
- Click `Move on` between element stages.
- Complete the existing correlation screens.
- Finish and assert `/strategies/:id` shows confirmed elements and a visible correlation strength.

**Step 2: Run tests to verify failure**

```bash
mix test test/x_matrix_web/live/interview_flow_test.exs
```

Expected: FAIL until the old correlation renderer works with the new chat flow.

**Step 3: Keep or extract existing correlation rendering**

Do not rewrite the correlation UI unless necessary. Preserve:

- `@correlation_pairs`
- `save_source` event
- `corr:intro:*` screens
- `corr:src:*` screens
- `review` screen and `finish` event

If the file is getting large, extract pure helpers into `XMatrixWeb.InterviewSteps` only after tests pass.

**Step 4: Run tests to verify pass**

```bash
mix test test/x_matrix_web/live/interview_flow_test.exs test/x_matrix_web/live/interview_live_test.exs
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex test/x_matrix_web/live/interview_flow_test.exs test/x_matrix_web/live/interview_live_test.exs
git commit -m "feat: connect chat interview to relationship ratings"
```

---

### Task 10: Resume restores transcript, matrix, stage, and drops transient proposals

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Test: `test/x_matrix_web/live/interview_flow_test.exs`
- Test: `test/x_matrix_web/live/interview_proposal_test.exs`

**Step 1: Write failing resume tests**

Tests:

- Create a draft at `chat:strategy`, add messages and confirmed elements, visit `/interview/:id`, assert transcript and emerging matrix render.
- Generate a proposal, navigate away, revisit `/interview/:id`, assert proposal card is gone but assistant/user transcript remains.
- Homepage `Resume interview` still reaches the chat interface.

**Step 2: Run tests to verify failure**

```bash
mix test test/x_matrix_web/live/interview_flow_test.exs test/x_matrix_web/live/interview_proposal_test.exs test/x_matrix_web/live/home_live_test.exs
```

Expected: FAIL until resume semantics are complete.

**Step 3: Implement resume loading**

Ensure `load/2` always reloads:

- strategy
- messages
- confirmed grouped elements
- correlations
- stage/current_step
- empty `pending_proposals`

Do not persist pending proposals.

**Step 4: Run tests to verify pass**

```bash
mix test test/x_matrix_web/live/interview_flow_test.exs test/x_matrix_web/live/interview_proposal_test.exs test/x_matrix_web/live/home_live_test.exs
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex test/x_matrix_web/live/interview_flow_test.exs test/x_matrix_web/live/interview_proposal_test.exs test/x_matrix_web/live/home_live_test.exs
git commit -m "feat: resume chat interview state"
```

---

### Task 11: AI toggle and no-key fallback

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Modify: `lib/x_matrix/strategies.ex`
- Modify: `config/runtime.exs`
- Test: `test/x_matrix_web/live/interview_live_test.exs`

**Step 1: Write failing tests**

Cover:

- Clicking the AI toggle updates `strategies.ai_assisted`.
- AI ON with no key displays a friendly notice and continues via scripted/manual mode.
- AI OFF never calls an Anthropic adapter. Use a test adapter that raises if called, or assert configured adapter is not invoked in scripted mode.

**Step 2: Run tests to verify failure**

```bash
mix test test/x_matrix_web/live/interview_live_test.exs
```

Expected: FAIL because toggle does not persist or display fallback notice.

**Step 3: Implement adapter selection**

Add a private helper in `InterviewLive` or a small module `XMatrix.LLM.Adapter`:

- If `strategy.ai_assisted == false`, use `XMatrix.LLM.Scripted`.
- If `strategy.ai_assisted == true` and `Application.get_env(:x_matrix, :anthropic_api_key)` is blank, use `XMatrix.LLM.Scripted` and set a notice.
- If key is present, use `Application.get_env(:x_matrix, :llm_adapter, XMatrix.LLM.Anthropic)`.
- In `:test`, keep the adapter deterministic.

In `config/runtime.exs` add:

```elixir
config :x_matrix,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  anthropic_model: System.get_env("ANTHROPIC_MODEL", "claude-3-5-haiku-latest")
```

**Step 4: Run tests to verify pass**

```bash
mix test test/x_matrix_web/live/interview_live_test.exs
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex lib/x_matrix/strategies.ex config/runtime.exs test/x_matrix_web/live/interview_live_test.exs
git commit -m "feat: toggle AI interview mode"
```

---

### Task 12: Add Anthropic adapter via Req

**Files:**
- Modify: `mix.exs`
- Create: `lib/x_matrix/llm/anthropic.ex`
- Test: `test/x_matrix/llm/anthropic_test.exs`

**Step 1: Add Req dependency**

In `mix.exs` deps add:

```elixir
{:req, "~> 0.5"}
```

Run:

```bash
mix deps.get
```

**Step 2: Write tests with a stubbed Req client**

Do not hit the network. Structure `XMatrix.LLM.Anthropic.facilitate/3` so HTTP can be injected, e.g. with `Application.get_env(:x_matrix, :anthropic_http, Req)` or a function option. Test that:

- Request includes `anthropic-version`, `x-api-key`, model, system prompt, messages, and a `propose_elements` tool.
- Tool-use response becomes structured proposals.
- Text-only response becomes assistant message with empty proposals.
- Error response returns `{:error, term}`.

**Step 3: Run tests to verify failure**

```bash
mix test test/x_matrix/llm/anthropic_test.exs
```

Expected: FAIL because adapter does not exist.

**Step 4: Implement adapter**

Use `Req.post/2`, not HTTPoison/Tesla/httpc. Build a system prompt per stage. Include strategy-stage guidance about genuine tension and `even over` statements. Keep context bounded to a recent message window, e.g. last 20 messages.

**Step 5: Run tests to verify pass**

```bash
mix test test/x_matrix/llm/anthropic_test.exs
```

Expected: PASS with no network.

**Step 6: Commit**

```bash
git add mix.exs mix.lock lib/x_matrix/llm/anthropic.ex test/x_matrix/llm/anthropic_test.exs
git commit -m "feat: add Anthropic facilitator adapter"
```

---

### Task 13: Polish chat UI and accessibility

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Optionally modify: `assets/css/app.css` only if Tailwind utilities are insufficient; do not use `@apply`.
- Test: existing LiveView tests

**Step 1: Add UI assertions for stable IDs and labels**

Add or update tests to assert:

- Input label is `Your answer`.
- Send button exists.
- `Move on` button exists only during element stages.
- Proposal Add/Edit/Dismiss buttons are accessible by text.
- Completed strategy matrix remains read-only.

**Step 2: Improve markup**

Use Tailwind classes for:

- sticky or visible TASTE progress indicator
- scrollable transcript region
- card-style assistant/user messages
- proposal cards with clear Add/Edit/Dismiss actions
- emerging matrix grouped by True North, Aspirations, Strategies, Evidence, Tactics
- subtle hover/focus transitions

Follow Phoenix rules:

- Keep `<Layouts.app flash={@flash}>` as the root.
- Use `<.input>` where it fits forms.
- Avoid inline `<script>`.
- Use `<.icon>` if icons are needed.

**Step 3: Run focused tests**

```bash
mix test test/x_matrix_web/live/interview_live_test.exs test/x_matrix_web/live/interview_proposal_test.exs test/x_matrix_web/live/interview_flow_test.exs
```

Expected: PASS.

**Step 4: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex assets/css/app.css test/x_matrix_web/live
git commit -m "style: polish conversational interview UI"
```

---

### Task 14: Full validation and docs/index update

**Files:**
- Modify: `docs/iterations/003-llm-led-interview/plan.md`
- Modify: `docs/iterations/README.md`

**Step 1: Mark iteration 003 ready for Fabro implementation, if using Fabro next**

If this plan is accepted and should be run by Fabro, update:

- `docs/iterations/003-llm-led-interview/plan.md` status from `proposed (design)` to `ready` or `fabro-ready`.
- `docs/iterations/README.md` status for 003 from `proposed` to `ready` or `fabro-ready`.

Do not mark it ready until Matt confirms this implementation plan is the intended scope.

**Step 2: Run full quality gate**

Run:

```bash
mix check
```

Expected: PASS with zero warnings. If PostgreSQL is not running, start it first; current local failure was `tcp connect (localhost:5432): connection refused`.

**Step 3: Final commit**

```bash
git add docs/iterations docs/plans
git commit -m "docs: prepare LLM interview implementation plan"
```

---

## Manual acceptance checklist

After implementation:

1. Visit `/interview`; confirm a draft opens in chat mode.
2. Confirm the page shows transcript, free-text input, emerging matrix, TASTE progress, and AI toggle.
3. With AI OFF, type one item per stage and confirm each immediately appears in the emerging matrix.
4. With AI ON and no `ANTHROPIC_API_KEY`, confirm a friendly fallback notice appears and scripted/manual entry still works.
5. With AI ON and a key, confirm proposal cards appear and nothing is saved until Add/Edit+Add.
6. Resume a draft and confirm transcript, confirmed matrix, and current stage restore; old pending proposal cards do not restore.
7. Complete relationship ratings and finish; confirm the strategy matrix is read-only.
8. Run `mix check` and confirm green.
