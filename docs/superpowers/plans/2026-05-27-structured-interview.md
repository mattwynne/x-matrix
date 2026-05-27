# Structured Interview (no LLM) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a guided linear interview that builds one new strategy from scratch in Karl Scotland's facilitation order, persisting each step so a draft can be resumed, ending on the read-only X-Matrix for the new strategy.

**Architecture:** A single `InterviewLive` LiveView drives a state machine over named steps held in `strategies.current_step`. Element steps add/remove `strategy_elements`; correlation steps render a rows×columns grid of strength dropdowns that upsert `strategy_correlations`. The existing read-only matrix moves from `/` to `/strategies/:id`, and `/` becomes a landing page. All writes go through new `XMatrix.Strategies` context functions. No LLM.

**Tech Stack:** Elixir, Phoenix 1.8 LiveView, Ecto/Postgres, Tailwind v4, `phoenix_test`.

---

## Reference: spec

Full spec at `docs/iterations/002-structured-interview/plan.md`. Read it before starting.

## File Structure

- `priv/repo/migrations/<ts>_add_strategy_interview_state.exs` — **create**: add `status` + `current_step` to `strategies`, backfill existing rows to `:complete`.
- `lib/x_matrix/strategies/strategy.ex` — **modify**: add `status`, `current_step` fields; cast them.
- `lib/x_matrix/strategies.ex` — **modify**: add write-side functions.
- `lib/x_matrix_web/router.ex` — **modify**: `/` → `HomeLive`; add `/strategies/:id`, `/interview`, `/interview/:id`.
- `lib/x_matrix_web/live/x_matrix_live.ex` + `.html.heex` — **modify**: load strategy by `:id` param instead of seeded.
- `lib/x_matrix_web/live/home_live.ex` — **create**: landing page.
- `lib/x_matrix_web/live/interview_live.ex` — **create**: the wizard.
- `test/...` — **create/modify**: tests per task.

## Step name vocabulary (used throughout)

Ordered `current_step` slugs (the single source of truth, defined in `InterviewLive`):

```
"true_north", "aspirations", "strategies", "strategy_aspiration",
"evidence", "evidence_aspiration", "tactics", "tactic_strategy",
"tactic_evidence", "review"
```

Correlation directions (source → target), matching the seed:

| Step slug             | Rows (source) | Columns (target) |
|-----------------------|---------------|------------------|
| `strategy_aspiration` | strategies    | aspirations      |
| `evidence_aspiration` | evidence      | aspirations      |
| `tactic_strategy`     | tactics       | strategies       |
| `tactic_evidence`     | tactics       | evidence         |

---

## Task 1: Draft state on the strategy

**Files:**
- Create: `priv/repo/migrations/<ts>_add_strategy_interview_state.exs`
- Modify: `lib/x_matrix/strategies/strategy.ex`
- Test: `test/x_matrix/strategies_test.exs`

- [ ] **Step 1: Generate the migration**

Run: `mix ecto.gen.migration add_strategy_interview_state`

Fill the generated file with:

```elixir
defmodule XMatrix.Repo.Migrations.AddStrategyInterviewState do
  use Ecto.Migration

  def change do
    alter table(:strategies) do
      add :status, :string, null: false, default: "draft"
      add :current_step, :string
    end

    # Existing/seeded rows are finished strategies, not drafts.
    execute(
      "UPDATE strategies SET status = 'complete'",
      "UPDATE strategies SET status = 'draft'"
    )
  end
end
```

- [ ] **Step 2: Add fields to the schema and changeset**

In `lib/x_matrix/strategies/strategy.ex`, add inside `schema "strategies"`:

```elixir
    field :status, Ecto.Enum, values: [:draft, :complete], default: :draft
    field :current_step, :string
```

Change the changeset to cast them:

```elixir
  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [:title, :description, :status, :current_step])
    |> validate_required([:title])
  end
```

- [ ] **Step 3: Write a migration smoke test**

Create `test/x_matrix/strategies_test.exs`:

```elixir
defmodule XMatrix.StrategiesTest do
  use XMatrix.DataCase, async: true

  alias XMatrix.Strategies
  alias XMatrix.Strategies.Strategy

  describe "draft state" do
    test "new strategies default to :draft" do
      {:ok, strategy} = Strategies.create_draft_strategy(%{title: "Untitled strategy"})
      assert strategy.status == :draft
      assert %Strategy{} = strategy
    end
  end
end
```

- [ ] **Step 4: Run the test (expect failure)**

Run: `MIX_ENV=test mix ecto.migrate && mix test test/x_matrix/strategies_test.exs`
Expected: FAIL — `create_draft_strategy/1` undefined (added in Task 2).

- [ ] **Step 5: Commit**

```bash
git add priv/repo/migrations lib/x_matrix/strategies/strategy.ex test/x_matrix/strategies_test.exs
git commit -m "Add draft status and current_step to strategies"
```

---

## Task 2: Context write functions

**Files:**
- Modify: `lib/x_matrix/strategies.ex`
- Test: `test/x_matrix/strategies_test.exs`

- [ ] **Step 1: Write failing tests for the write functions**

Replace the body of `test/x_matrix/strategies_test.exs` with:

```elixir
defmodule XMatrix.StrategiesTest do
  use XMatrix.DataCase, async: true

  alias XMatrix.Strategies

  setup do
    {:ok, strategy} = Strategies.create_draft_strategy(%{title: "Untitled strategy"})
    %{strategy: strategy}
  end

  test "create_draft_strategy/1 starts a draft", %{strategy: strategy} do
    assert strategy.status == :draft
  end

  test "update_strategy/2 changes the title", %{strategy: strategy} do
    {:ok, updated} = Strategies.update_strategy(strategy, %{title: "Housing"})
    assert updated.title == "Housing"
  end

  test "add_element/2 appends with an incrementing position", %{strategy: strategy} do
    {:ok, a} = Strategies.add_element(strategy, %{element_type: :aspiration, title: "A1"})
    {:ok, b} = Strategies.add_element(strategy, %{element_type: :aspiration, title: "A2"})
    assert a.position == 1
    assert b.position == 2
  end

  test "delete_element/1 removes it", %{strategy: strategy} do
    {:ok, a} = Strategies.add_element(strategy, %{element_type: :tactic, title: "T1"})
    {:ok, _} = Strategies.delete_element(a)
    assert Strategies.get_strategy!(strategy.id).elements == []
  end

  test "upsert_correlation/4 sets then clears a pair", %{strategy: strategy} do
    {:ok, s} = Strategies.add_element(strategy, %{element_type: :strategy, title: "S"})
    {:ok, asp} = Strategies.add_element(strategy, %{element_type: :aspiration, title: "A"})

    {:ok, _} = Strategies.upsert_correlation(strategy, s, asp, :strong)
    reloaded = Strategies.get_strategy!(strategy.id)
    assert [corr] = reloaded.correlations
    assert corr.strength == :strong
    assert corr.source_element_id == s.id
    assert corr.target_element_id == asp.id

    {:ok, _} = Strategies.upsert_correlation(strategy, s, asp, :none)
    assert Strategies.get_strategy!(strategy.id).correlations == []
  end

  test "set_step/2 and complete_strategy/1", %{strategy: strategy} do
    {:ok, stepped} = Strategies.set_step(strategy, "tactics")
    assert stepped.current_step == "tactics"
    {:ok, done} = Strategies.complete_strategy(strategy)
    assert done.status == :complete
  end

  test "get_resumable_draft/0 returns the latest draft, ignoring complete", %{strategy: strategy} do
    assert Strategies.get_resumable_draft().id == strategy.id
    {:ok, _} = Strategies.complete_strategy(strategy)
    assert Strategies.get_resumable_draft() == nil
  end
end
```

- [ ] **Step 2: Run tests (expect failure)**

Run: `mix test test/x_matrix/strategies_test.exs`
Expected: FAIL — functions undefined.

- [ ] **Step 3: Implement the context functions**

In `lib/x_matrix/strategies.ex`, add the alias and functions. Add to the top aliases:

```elixir
  alias XMatrix.Strategies.{Strategy, StrategyCorrelation, StrategyElement}
```

(remove the now-redundant single `alias ... Strategy` line). Then generalise loading and add writes:

```elixir
  @doc "Load any strategy with elements (ordered) and correlations preloaded."
  def get_strategy!(id) do
    Strategy
    |> Repo.get!(id)
    |> preload_ordered()
  end

  def get_seeded_strategy! do
    Strategy
    |> order_by([s], asc: s.inserted_at, asc: s.id)
    |> limit(1)
    |> Repo.one!()
    |> then(&get_strategy!(&1.id))
  end

  defp preload_ordered(strategy) do
    Repo.preload(
      strategy,
      [
        elements: from(e in StrategyElement, order_by: [asc: e.position, asc: e.id]),
        correlations:
          from(c in StrategyCorrelation,
            order_by: [asc: c.id],
            preload: [:source_element, :target_element]
          )
      ],
      force: true
    )
  end

  def create_draft_strategy(attrs) do
    %Strategy{}
    |> Strategy.changeset(Map.merge(%{status: :draft, current_step: "true_north"}, attrs))
    |> Repo.insert()
  end

  def update_strategy(%Strategy{} = strategy, attrs) do
    strategy |> Strategy.changeset(attrs) |> Repo.update()
  end

  def set_step(%Strategy{} = strategy, step) when is_binary(step) do
    strategy |> Strategy.changeset(%{current_step: step}) |> Repo.update()
  end

  def complete_strategy(%Strategy{} = strategy) do
    strategy |> Strategy.changeset(%{status: :complete, current_step: "review"}) |> Repo.update()
  end

  def get_resumable_draft do
    Strategy
    |> where([s], s.status == :draft)
    |> order_by([s], desc: s.updated_at, desc: s.id)
    |> limit(1)
    |> Repo.one()
  end

  def add_element(%Strategy{} = strategy, attrs) do
    next_position =
      StrategyElement
      |> where([e], e.strategy_id == ^strategy.id)
      |> select([e], count(e.id))
      |> Repo.one()
      |> Kernel.+(1)

    %StrategyElement{}
    |> StrategyElement.changeset(
      attrs
      |> Map.put(:strategy_id, strategy.id)
      |> Map.put(:position, next_position)
    )
    |> Repo.insert()
  end

  def update_element(%StrategyElement{} = element, attrs) do
    element |> StrategyElement.changeset(attrs) |> Repo.update()
  end

  def delete_element(%StrategyElement{} = element), do: Repo.delete(element)

  @doc "Set (or clear, when strength is :none) the correlation for a source→target pair."
  def upsert_correlation(%Strategy{} = strategy, source, target, strength) do
    existing =
      StrategyCorrelation
      |> Repo.get_by(
        strategy_id: strategy.id,
        source_element_id: source.id,
        target_element_id: target.id
      )

    cond do
      strength == :none and is_nil(existing) ->
        {:ok, nil}

      strength == :none ->
        Repo.delete(existing)

      true ->
        (existing || %StrategyCorrelation{})
        |> StrategyCorrelation.changeset(%{
          strategy_id: strategy.id,
          source_element_id: source.id,
          target_element_id: target.id,
          strength: strength
        })
        |> Repo.insert_or_update()
    end
  end
```

Note: `timestamps(type: :utc_datetime)` already gives `updated_at` used by `get_resumable_draft/0`.

- [ ] **Step 4: Run tests (expect pass)**

Run: `mix test test/x_matrix/strategies_test.exs`
Expected: PASS (all 7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/x_matrix/strategies.ex test/x_matrix/strategies_test.exs
git commit -m "Add write-side strategy context functions"
```

---

## Task 3: Move the read-only matrix to /strategies/:id

**Files:**
- Modify: `lib/x_matrix_web/router.ex`
- Modify: `lib/x_matrix_web/live/x_matrix_live.ex`
- Modify: `test/x_matrix_web/live/x_matrix_live_test.exs`

- [ ] **Step 1: Update the matrix test to visit /strategies/:id**

In `test/x_matrix_web/live/x_matrix_live_test.exs`, the `setup` already inserts a strategy and returns `:ok`. Change it to also return the strategy, and update the visit. Replace `:ok` at the end of `setup` with `%{strategy: strategy}`, and change the test signature and first line:

```elixir
  test "renders the read-only X-Matrix", %{conn: conn, strategy: strategy} do
    conn
    |> visit("/strategies/#{strategy.id}")
    |> assert_has("h1", text: "Multi-agency homelessness reduction strategy")
```

(leave the remaining assertions unchanged).

- [ ] **Step 2: Route the matrix at /strategies/:id**

In `lib/x_matrix_web/router.ex`, inside the `scope "/"`, replace `live "/", XMatrixLive, :home` with:

```elixir
    live "/strategies/:id", XMatrixLive, :show
```

(The `/` route is added in Task 4.)

- [ ] **Step 3: Load by id in the LiveView**

In `lib/x_matrix_web/live/x_matrix_live.ex`, change `mount/3`:

```elixir
  @impl true
  def mount(%{"id" => id}, _session, socket) do
    strategy = Strategies.get_strategy!(id)

    {:ok,
     socket
     |> assign(:strategy, strategy)
     |> assign(:true_north, Strategies.elements_by_type(strategy, :true_north))
     |> assign(:aspirations, Strategies.elements_by_type(strategy, :aspiration))
     |> assign(:strategies, Strategies.elements_by_type(strategy, :strategy))
     |> assign(:evidence, Strategies.elements_by_type(strategy, :evidence))
     |> assign(:tactics, Strategies.elements_by_type(strategy, :tactic))}
  end
```

- [ ] **Step 4: Run the matrix test (expect pass)**

Run: `mix test test/x_matrix_web/live/x_matrix_live_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/x_matrix_web/router.ex lib/x_matrix_web/live/x_matrix_live.ex test/x_matrix_web/live/x_matrix_live_test.exs
git commit -m "Serve read-only matrix at /strategies/:id"
```

---

## Task 4: Landing page at /

**Files:**
- Create: `lib/x_matrix_web/live/home_live.ex`
- Modify: `lib/x_matrix_web/router.ex`
- Test: `test/x_matrix_web/live/home_live_test.exs`

- [ ] **Step 1: Write the failing landing test**

Create `test/x_matrix_web/live/home_live_test.exs`:

```elixir
defmodule XMatrixWeb.HomeLiveTest do
  use XMatrixWeb.ConnCase, async: true

  alias XMatrix.Strategies

  test "shows the three choices and links to the example matrix", %{conn: conn} do
    {:ok, example} = Strategies.create_draft_strategy(%{title: "Example"})
    {:ok, _} = Strategies.complete_strategy(example)

    conn
    |> visit("/")
    |> assert_has("a", text: "View example matrix")
    |> assert_has("a", text: "Start interview")
    |> refute_has("a", text: "Resume interview")
  end

  test "shows resume when a draft exists", %{conn: conn} do
    {:ok, _draft} = Strategies.create_draft_strategy(%{title: "WIP"})

    conn
    |> visit("/")
    |> assert_has("a", text: "Resume interview")
  end
end
```

- [ ] **Step 2: Run the test (expect failure)**

Run: `mix test test/x_matrix_web/live/home_live_test.exs`
Expected: FAIL — no `/` route / module missing.

- [ ] **Step 3: Create the landing LiveView**

Create `lib/x_matrix_web/live/home_live.ex`:

```elixir
defmodule XMatrixWeb.HomeLive do
  use XMatrixWeb, :live_view

  alias XMatrix.Strategies

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:example, Strategies.get_seeded_strategy!())
     |> assign(:draft, Strategies.get_resumable_draft())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="mx-auto max-w-2xl p-8 text-center">
        <h1 class="text-3xl font-bold text-slate-950">X-Matrix</h1>
        <p class="mt-3 text-slate-600">
          Build a strategy through a guided interview, in the X-Matrix facilitation order.
        </p>

        <div class="mt-8 flex flex-col gap-3">
          <.link
            navigate={~p"/strategies/#{@example.id}"}
            class="rounded-xl border border-slate-300 px-5 py-3 font-medium text-slate-800 hover:bg-slate-50"
          >
            View example matrix
          </.link>

          <.link
            navigate={~p"/interview"}
            class="rounded-xl bg-indigo-700 px-5 py-3 font-semibold text-white hover:bg-indigo-800"
          >
            Start interview
          </.link>

          <.link
            :if={@draft}
            navigate={~p"/interview/#{@draft.id}"}
            class="rounded-xl border border-indigo-300 px-5 py-3 font-medium text-indigo-700 hover:bg-indigo-50"
          >
            Resume interview
          </.link>
        </div>
      </main>
    </Layouts.app>
    """
  end
end
```

- [ ] **Step 4: Add the `/` route**

In `lib/x_matrix_web/router.ex`, inside `scope "/"`, above the `/strategies/:id` line:

```elixir
    live "/", HomeLive, :home
```

- [ ] **Step 5: Run tests (expect pass)**

Run: `mix test test/x_matrix_web/live/home_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/x_matrix_web/live/home_live.ex lib/x_matrix_web/router.ex test/x_matrix_web/live/home_live_test.exs
git commit -m "Add landing page with view/start/resume choices"
```

---

## Task 5: Interview scaffolding — start draft, step machine, navigation

**Files:**
- Create: `lib/x_matrix_web/live/interview_live.ex`
- Modify: `lib/x_matrix_web/router.ex`
- Test: `test/x_matrix_web/live/interview_live_test.exs`

- [ ] **Step 1: Write the failing scaffolding test**

Create `test/x_matrix_web/live/interview_live_test.exs`:

```elixir
defmodule XMatrixWeb.InterviewLiveTest do
  use XMatrixWeb.ConnCase, async: true

  alias XMatrix.Strategies

  test "starting an interview creates a draft and opens step 1", %{conn: conn} do
    conn
    |> visit("/interview")
    |> assert_has("h1", text: "True North")

    assert Strategies.get_resumable_draft() != nil
  end

  test "back is disabled on the first step", %{conn: conn} do
    conn
    |> visit("/interview")
    |> refute_has("button", text: "Back")
  end
end
```

- [ ] **Step 2: Run the test (expect failure)**

Run: `mix test test/x_matrix_web/live/interview_live_test.exs`
Expected: FAIL — no route/module.

- [ ] **Step 3: Create the InterviewLive skeleton**

Create `lib/x_matrix_web/live/interview_live.ex`:

```elixir
defmodule XMatrixWeb.InterviewLive do
  use XMatrixWeb, :live_view

  alias XMatrix.Strategies

  @steps ~w(true_north aspirations strategies strategy_aspiration evidence
            evidence_aspiration tactics tactic_strategy tactic_evidence review)

  @step_titles %{
    "true_north" => "True North",
    "aspirations" => "Aspirations",
    "strategies" => "Strategies",
    "strategy_aspiration" => "Strategies → Aspirations",
    "evidence" => "Evidence",
    "evidence_aspiration" => "Evidence → Aspirations",
    "tactics" => "Tactics",
    "tactic_strategy" => "Tactics → Strategies",
    "tactic_evidence" => "Tactics → Evidence",
    "review" => "Review"
  }

  # {rows_assign, cols_assign} — source is rows, target is cols.
  # Used here for `correlation_step?`; the grid renderer is added in a later task.
  @correlation_steps %{
    "strategy_aspiration" => {:strategies, :aspirations},
    "evidence_aspiration" => {:evidence, :aspirations},
    "tactic_strategy" => {:tactics, :strategies},
    "tactic_evidence" => {:tactics, :evidence}
  }

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, load(socket, id)}
  end

  def mount(_params, _session, socket) do
    {:ok, draft} = Strategies.create_draft_strategy(%{title: "Untitled strategy"})
    {:ok, push_navigate(socket, to: ~p"/interview/#{draft.id}")}
  end

  defp load(socket, id) do
    strategy = Strategies.get_strategy!(id)
    assign_strategy(socket, strategy)
  end

  defp assign_strategy(socket, strategy) do
    step = strategy.current_step || "true_north"

    socket
    |> assign(:strategy, strategy)
    |> assign(:step, step)
    |> assign(:step_title, @step_titles[step])
    |> assign(:step_number, index(step) + 1)
    |> assign(:step_count, length(@steps))
    |> assign(:first_step?, index(step) == 0)
    |> assign(:correlation_step?, Map.has_key?(@correlation_steps, step))
    |> assign(:true_north, Strategies.elements_by_type(strategy, :true_north))
    |> assign(:aspirations, Strategies.elements_by_type(strategy, :aspiration))
    |> assign(:strategies, Strategies.elements_by_type(strategy, :strategy))
    |> assign(:evidence, Strategies.elements_by_type(strategy, :evidence))
    |> assign(:tactics, Strategies.elements_by_type(strategy, :tactic))
  end

  @impl true
  def handle_event("next", _params, socket) do
    {:noreply, goto(socket, next_step(socket.assigns.step))}
  end

  def handle_event("back", _params, socket) do
    {:noreply, goto(socket, prev_step(socket.assigns.step))}
  end

  defp goto(socket, step) do
    {:ok, strategy} = Strategies.set_step(socket.assigns.strategy, step)
    assign_strategy(socket, strategy)
  end

  defp next_step(step), do: Enum.at(@steps, min(index(step) + 1, length(@steps) - 1))
  defp prev_step(step), do: Enum.at(@steps, max(index(step) - 1, 0))
  defp index(step), do: Enum.find_index(@steps, &(&1 == step)) || 0

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="mx-auto max-w-3xl p-8">
        <p class="text-sm font-semibold uppercase tracking-wide text-indigo-700">
          Step {@step_number} of {@step_count}
        </p>
        <h1 class="mt-1 text-3xl font-bold text-slate-950">{@step_title}</h1>

        <div class="mt-6">
          {render_step(assigns)}
        </div>

        <div class="mt-8 flex justify-between">
          <button
            :if={not @first_step?}
            type="button"
            phx-click="back"
            class="rounded-lg border border-slate-300 px-4 py-2 font-medium text-slate-700"
          >
            Back
          </button>
          <span :if={@first_step?}></span>

          <button
            :if={@step != "review" and not @correlation_step?}
            type="button"
            phx-click="next"
            class="rounded-lg bg-indigo-700 px-4 py-2 font-semibold text-white"
          >
            Next
          </button>
        </div>
      </main>
    </Layouts.app>
    """
  end

  # Placeholder until later tasks add real step bodies.
  defp render_step(assigns) do
    ~H"""
    <p class="text-slate-600">Step content for {@step}.</p>
    """
  end
end
```

Note on template references: the header (`@step_number`, `@step_count`,
`@step_title`) and footer guards (`@first_step?`, `@correlation_step?`) all read
**assigns** set in `assign_strategy/2`, never module attributes — `@foo` in HEEx
always means `assigns.foo`.

- [ ] **Step 4: Add interview routes**

In `lib/x_matrix_web/router.ex`, inside `scope "/"`:

```elixir
    live "/interview", InterviewLive, :new
    live "/interview/:id", InterviewLive, :edit
```

- [ ] **Step 5: Run tests (expect pass)**

Run: `mix test test/x_matrix_web/live/interview_live_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex lib/x_matrix_web/router.ex test/x_matrix_web/live/interview_live_test.exs
git commit -m "Add interview wizard scaffolding and step navigation"
```

---

## Task 6: Element steps (True North, Aspirations, Strategies, Evidence, Tactics)

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Test: `test/x_matrix_web/live/interview_live_test.exs`

Element steps share one renderer. True North also edits the strategy name and is limited to one element.

- [ ] **Step 1: Write failing tests for element entry**

Add to `test/x_matrix_web/live/interview_live_test.exs`:

```elixir
  test "step 1 sets the strategy name and a single True North", %{conn: conn} do
    session =
      conn
      |> visit("/interview")
      |> fill_in("Strategy name", with: "Homelessness")
      |> fill_in("True North", with: "Everyone has a home")
      |> click_button("Save True North")

    session
    |> assert_has("li", text: "Everyone has a home")
    |> refute_has("input[name='element[title]']")
  end

  test "an element step adds and removes multiple items", %{conn: conn} do
    {:ok, strategy} = Strategies.create_draft_strategy(%{title: "S", current_step: "aspirations"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Title", with: "Reduce rough sleeping")
    |> click_button("Add")
    |> assert_has("li", text: "Reduce rough sleeping")
    |> fill_in("Title", with: "Second aspiration")
    |> click_button("Add")
    |> assert_has("li", text: "Second aspiration")
    |> click_button("Remove Second aspiration")
    |> refute_has("li", text: "Second aspiration")
  end
```

- [ ] **Step 2: Run the tests (expect failure)**

Run: `mix test test/x_matrix_web/live/interview_live_test.exs`
Expected: FAIL — placeholder step body, no forms.

- [ ] **Step 3: Implement element-step rendering and events**

In `lib/x_matrix_web/live/interview_live.ex`, add an `element_type` mapping and replace `render_step/1` with a dispatcher. **Keep every `render_step/1` clause contiguous** (Tasks 7 and 8 add more clauses to this same group; the catch-all must always be last) — non-grouped clauses warn and fail `--warnings-as-errors`. Add near the top:

```elixir
  @element_steps %{
    "true_north" => :true_north,
    "aspirations" => :aspiration,
    "strategies" => :strategy,
    "evidence" => :evidence,
    "tactics" => :tactic
  }
```

Replace `render_step/1` with:

```elixir
  defp render_step(%{step: "true_north"} = assigns) do
    ~H"""
    <div class="space-y-6">
      <form phx-submit="save_true_north" id="true-north-form" class="space-y-4">
        <.input name="title" value={@strategy.title} label="Strategy name" />
        <.input
          name="element[title]"
          value=""
          label="True North"
          placeholder="The orienting direction"
        />
        <.input type="textarea" name="element[description]" value="" label="Description" />
        <button :if={@true_north == []} class="rounded-lg bg-slate-800 px-4 py-2 text-white">
          Save True North
        </button>
      </form>

      <ul class="space-y-2">
        <li :for={el <- @true_north} class="rounded-lg border border-slate-200 p-3">
          <span class="font-semibold">{el.title}</span>
        </li>
      </ul>
    </div>
    """
  end

  defp render_step(%{step: step} = assigns) when is_map_key(@element_steps, step) do
    assigns = assign(assigns, :items, items_for(assigns, step))

    ~H"""
    <div class="space-y-6">
      <form phx-submit="add_element" id="element-form" class="space-y-4">
        <.input name="element[title]" value="" label="Title" />
        <.input type="textarea" name="element[description]" value="" label="Description" />
        <button class="rounded-lg bg-slate-800 px-4 py-2 text-white">Add</button>
      </form>

      <ul class="space-y-2">
        <li
          :for={el <- @items}
          class="flex items-center justify-between rounded-lg border border-slate-200 p-3"
        >
          <span class="font-semibold">{el.title}</span>
          <button
            type="button"
            phx-click="delete_element"
            phx-value-id={el.id}
            class="text-sm text-red-600"
          >
            Remove {el.title}
          </button>
        </li>
      </ul>
    </div>
    """
  end

  defp render_step(assigns) do
    ~H"""
    <p class="text-slate-600">Step content for {@step}.</p>
    """
  end

  defp items_for(assigns, step) do
    case @element_steps[step] do
      :aspiration -> assigns.aspirations
      :strategy -> assigns.strategies
      :evidence -> assigns.evidence
      :tactic -> assigns.tactics
    end
  end
```

Add the event handlers:

```elixir
  def handle_event("save_true_north", %{"title" => title, "element" => element}, socket) do
    {:ok, strategy} = Strategies.update_strategy(socket.assigns.strategy, %{title: title})

    if socket.assigns.true_north == [] and element["title"] not in [nil, ""] do
      {:ok, _} =
        Strategies.add_element(strategy, %{
          element_type: :true_north,
          title: element["title"],
          description: element["description"]
        })
    end

    {:noreply, load(socket, strategy.id)}
  end

  def handle_event("add_element", %{"element" => element}, socket) do
    type = @element_steps[socket.assigns.step]

    if element["title"] in [nil, ""] do
      {:noreply, socket}
    else
      {:ok, _} =
        Strategies.add_element(socket.assigns.strategy, %{
          element_type: type,
          title: element["title"],
          description: element["description"]
        })

      {:noreply, load(socket, socket.assigns.strategy.id)}
    end
  end

  def handle_event("delete_element", %{"id" => id}, socket) do
    element = Enum.find(all_elements(socket.assigns), &(to_string(&1.id) == id))
    if element, do: Strategies.delete_element(element)
    {:noreply, load(socket, socket.assigns.strategy.id)}
  end

  defp all_elements(assigns) do
    assigns.true_north ++ assigns.aspirations ++ assigns.strategies ++
      assigns.evidence ++ assigns.tactics
  end
```

Note: `StrategyElement.changeset` accepts `element_type` as an atom or string via `Ecto.Enum` casting; the `add_element` attrs use string keys merged with `"element_type"`.

- [ ] **Step 4: Run tests (expect pass)**

Run: `mix test test/x_matrix_web/live/interview_live_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex test/x_matrix_web/live/interview_live_test.exs
git commit -m "Add element entry steps to the interview"
```

---

## Task 7: Correlation grid steps

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Test: `test/x_matrix_web/live/interview_live_test.exs`

- [ ] **Step 1: Write the failing correlation test**

Add to `test/x_matrix_web/live/interview_live_test.exs`:

```elixir
  test "strategy_aspiration step saves a strength per pair", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "S", current_step: "strategy_aspiration"})

    {:ok, strat} = Strategies.add_element(strategy, %{element_type: :strategy, title: "Strat A"})
    {:ok, asp} = Strategies.add_element(strategy, %{element_type: :aspiration, title: "Asp A"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("h1", text: "Strategies → Aspirations")
    |> select("strong", from: "#{strat.title} → #{asp.title}")
    |> click_button("Next")

    reloaded = Strategies.get_strategy!(strategy.id)
    assert [corr] = reloaded.correlations
    assert corr.strength == :strong
    assert corr.source_element_id == strat.id
    assert corr.target_element_id == asp.id
  end
```

- [ ] **Step 2: Run the test (expect failure)**

Run: `mix test test/x_matrix_web/live/interview_live_test.exs`
Expected: FAIL — correlation step renders placeholder; `Next` doesn't save grid.

- [ ] **Step 3: Implement the correlation grid step**

`@correlation_steps` is already defined (Task 5). Add the strength options near the top:

```elixir
  @strength_options [{"—", "none"}, {"weak", "weak"}, {"medium", "medium"}, {"strong", "strong"}]
```

Add a `render_step/1` clause **above** the catch-all:

```elixir
  defp render_step(%{step: step} = assigns) when is_map_key(@correlation_steps, step) do
    {rows_key, cols_key} = @correlation_steps[step]
    rows = Map.fetch!(assigns, rows_key)
    cols = Map.fetch!(assigns, cols_key)
    assigns = assign(assigns, rows: rows, cols: cols, strength_options: @strength_options)

    ~H"""
    <form phx-submit="save_correlations" id="correlation-form">
      <div class="overflow-x-auto">
        <table class="border-collapse">
          <thead>
            <tr>
              <th></th>
              <th :for={col <- @cols} class="p-2 text-left text-sm font-semibold">{col.title}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows}>
              <th class="p-2 text-left text-sm font-semibold">{row.title}</th>
              <td :for={col <- @cols} class="p-2">
                <label class="sr-only" for={"corr-#{row.id}-#{col.id}"}>
                  {row.title} → {col.title}
                </label>
                <select
                  id={"corr-#{row.id}-#{col.id}"}
                  name={"corr[#{row.id}_#{col.id}]"}
                  class="rounded border border-slate-300 px-2 py-1"
                >
                  <option
                    :for={{label, value} <- @strength_options}
                    value={value}
                    selected={value == current_strength(@strategy, row, col)}
                  >
                    {label}
                  </option>
                </select>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <button class="mt-6 rounded-lg bg-indigo-700 px-4 py-2 font-semibold text-white">Next</button>
    </form>
    """
  end

  defp current_strength(strategy, source, target) do
    case Enum.find(strategy.correlations, fn c ->
           c.source_element_id == source.id and c.target_element_id == target.id
         end) do
      nil -> "none"
      corr -> to_string(corr.strength)
    end
  end
```

Add the save handler. It parses `corr[<src>_<tgt>]` params, upserts each, then advances:

```elixir
  def handle_event("save_correlations", %{"corr" => pairs}, socket) do
    strategy = socket.assigns.strategy
    elements_by_id = Map.new(all_elements(socket.assigns), &{to_string(&1.id), &1})

    Enum.each(pairs, fn {key, strength} ->
      [src_id, tgt_id] = String.split(key, "_")
      source = Map.fetch!(elements_by_id, src_id)
      target = Map.fetch!(elements_by_id, tgt_id)
      Strategies.upsert_correlation(strategy, source, target, String.to_existing_atom(strength))
    end)

    {:noreply, goto(socket, next_step(socket.assigns.step))}
  end

  # A correlation step with no rows or columns has no form; allow Next to skip.
  def handle_event("save_correlations", _params, socket) do
    {:noreply, goto(socket, next_step(socket.assigns.step))}
  end
```

`String.to_existing_atom/1` is safe here: `:none/:weak/:medium/:strong` are all defined as `Ecto.Enum` values, so the atoms already exist.

**Note:** on correlation steps the footer `Next` button is already hidden — the
`render/1` footer guard is `:if={@step != "review" and not @correlation_step?}`,
and `@correlation_step?` was assigned in `assign_strategy` (Task 5). The grid
form supplies its own `Next` submit button that fires `save_correlations`.

- [ ] **Step 4: Run tests (expect pass)**

Run: `mix test test/x_matrix_web/live/interview_live_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex test/x_matrix_web/live/interview_live_test.exs
git commit -m "Add correlation grid steps to the interview"
```

---

## Task 8: Review step and finish

**Files:**
- Modify: `lib/x_matrix_web/live/interview_live.ex`
- Test: `test/x_matrix_web/live/interview_live_test.exs`

- [ ] **Step 1: Write the failing finish test**

Add to `test/x_matrix_web/live/interview_live_test.exs`:

```elixir
  test "review step finishes and navigates to the matrix", %{conn: conn} do
    {:ok, strategy} = Strategies.create_draft_strategy(%{title: "Done", current_step: "review"})
    {:ok, _} = Strategies.add_element(strategy, %{element_type: :true_north, title: "TN"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> click_button("Finish")
    |> assert_path("/strategies/#{strategy.id}")

    assert Strategies.get_strategy!(strategy.id).status == :complete
  end
```

- [ ] **Step 2: Run the test (expect failure)**

Run: `mix test test/x_matrix_web/live/interview_live_test.exs`
Expected: FAIL — no Finish button on review.

- [ ] **Step 3: Implement the review step and finish handler**

Add a `render_step/1` clause for `"review"` (above the catch-all):

```elixir
  defp render_step(%{step: "review"} = assigns) do
    ~H"""
    <div class="space-y-4">
      <p class="text-slate-600">
        You've worked through every step. Finishing will mark this strategy complete
        and show its X-Matrix.
      </p>
      <ul class="grid grid-cols-2 gap-3 text-sm">
        <li class="rounded-lg border border-slate-200 p-3">True North: {length(@true_north)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Aspirations: {length(@aspirations)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Strategies: {length(@strategies)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Evidence: {length(@evidence)}</li>
        <li class="rounded-lg border border-slate-200 p-3">Tactics: {length(@tactics)}</li>
      </ul>
      <button
        type="button"
        phx-click="finish"
        class="rounded-lg bg-indigo-700 px-4 py-2 font-semibold text-white"
      >
        Finish
      </button>
    </div>
    """
  end
```

Add the handler:

```elixir
  def handle_event("finish", _params, socket) do
    {:ok, strategy} = Strategies.complete_strategy(socket.assigns.strategy)
    {:noreply, push_navigate(socket, to: ~p"/strategies/#{strategy.id}")}
  end
```

- [ ] **Step 4: Run tests (expect pass)**

Run: `mix test test/x_matrix_web/live/interview_live_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/x_matrix_web/live/interview_live.ex test/x_matrix_web/live/interview_live_test.exs
git commit -m "Add review step and finish to the interview"
```

---

## Task 9: Full walkthrough, resume, persistence, and dev check

**Files:**
- Test: `test/x_matrix_web/live/interview_flow_test.exs`

- [ ] **Step 1: Write an end-to-end walkthrough test**

Create `test/x_matrix_web/live/interview_flow_test.exs`:

```elixir
defmodule XMatrixWeb.InterviewFlowTest do
  use XMatrixWeb.ConnCase, async: true

  alias XMatrix.Strategies

  test "build a strategy end to end and land on its matrix", %{conn: conn} do
    session =
      conn
      |> visit("/interview")
      |> fill_in("Strategy name", with: "Homelessness")
      |> fill_in("True North", with: "Everyone has a home")
      |> click_button("Save True North")
      |> click_button("Next")
      # aspirations
      |> fill_in("Title", with: "Reduce rough sleeping")
      |> click_button("Add")
      |> click_button("Next")
      # strategies
      |> fill_in("Title", with: "Intervene before crisis")
      |> click_button("Add")
      |> click_button("Next")
      # strategy_aspiration grid -> Next saves
      |> click_button("Next")
      # evidence
      |> fill_in("Title", with: "Days to stable housing")
      |> click_button("Add")
      |> click_button("Next")
      # evidence_aspiration grid
      |> click_button("Next")
      # tactics
      |> fill_in("Title", with: "By-name case conference")
      |> click_button("Add")
      |> click_button("Next")
      # tactic_strategy grid
      |> click_button("Next")
      # tactic_evidence grid
      |> click_button("Next")

    session
    |> assert_has("h1", text: "Review")
    |> click_button("Finish")
    |> assert_has("h1", text: "Homelessness")
    |> assert_has("h2", text: "True North")
    |> assert_has("span", text: "Reduce rough sleeping")
    |> assert_has("span", text: "Intervene before crisis")
    |> assert_has("span", text: "Days to stable housing")
    |> assert_has("span", text: "By-name case conference")
  end

  test "resume reopens at the saved step with prior data", %{conn: conn} do
    {:ok, strategy} = Strategies.create_draft_strategy(%{title: "WIP", current_step: "strategies"})
    {:ok, _} = Strategies.add_element(strategy, %{element_type: :strategy, title: "Kept item"})

    conn
    |> visit("/")
    |> click_link("Resume interview")
    |> assert_has("h1", text: "Strategies")
    |> assert_has("li", text: "Kept item")
  end

  test "tactics cannot be reached before evidence", %{conn: conn} do
    {:ok, strategy} = Strategies.create_draft_strategy(%{title: "WIP", current_step: "strategies"})

    # From 'strategies', a single Next advances to the strategy_aspiration grid,
    # not to tactics.
    conn
    |> visit("/interview/#{strategy.id}")
    |> click_button("Next")
    |> assert_has("h1", text: "Strategies → Aspirations")
    |> refute_has("h1", text: "Tactics")
  end

  test "entered data persists across a reload mid-interview", %{conn: conn} do
    {:ok, strategy} = Strategies.create_draft_strategy(%{title: "WIP", current_step: "aspirations"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Title", with: "Persisted aspiration")
    |> click_button("Add")

    # Fresh visit simulates a reload.
    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("li", text: "Persisted aspiration")
  end
end
```

- [ ] **Step 2: Run the flow tests**

Run: `mix test test/x_matrix_web/live/interview_flow_test.exs`
Expected: PASS. If a selector fails, debug with `LazyHTML` as in AGENTS.md before changing assertions.

- [ ] **Step 3: Run the full check**

Run: `./dev check`
Expected: PASS — `format --check-formatted`, `compile --warnings-as-errors`, and `test` all green. Run `mix format` if formatting fails, fix any compile warnings (e.g. unused `steps/0` helper — remove dead code), and re-run.

- [ ] **Step 4: Commit**

```bash
git add test/x_matrix_web/live/interview_flow_test.exs
git commit -m "Add end-to-end interview flow, resume, and persistence tests"
```

---

## Manual validation (after all tasks)

1. `mix ecto.reset` (recreates, migrates, seeds) and `mix phx.server`.
2. Visit `/`; confirm the three choices; "View example matrix" shows the seeded matrix.
3. Start an interview; walk all steps; confirm Tactics can't be reached before Evidence.
4. Reload mid-interview; confirm data and step preserved.
5. Leave, return to `/`, click "Resume interview".
6. Finish; confirm the new strategy renders read-only with all five element types and visible correlation strengths.

## Self-review notes

- **Spec coverage:** landing (Task 4), matrix-by-id (Task 3), draft state + migration (Task 1), context writes (Task 2), wizard + order enforcement (Task 5), element steps (Task 6), correlation grids with direction table (Task 7), review/finish + navigate (Task 8), resume + incremental persistence + order tests (Task 9). All acceptance criteria map to a task.
- **Order enforcement** is structural: `next_step/1` walks the fixed `@steps` list, so there is no way to reach a later step without stepping through the intermediate ones; Task 9 asserts this.
- **Naming consistency:** `current_step` (string slugs), `@steps`, `@element_steps`, `@correlation_steps`, `upsert_correlation/4`, `get_strategy!/1`, `set_step/2`, `complete_strategy/1`, `get_resumable_draft/0` are used identically across tasks.
