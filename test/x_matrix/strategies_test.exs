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

  test "create_draft_strategy/1 stores ai_assisted" do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "AI draft", ai_assisted: true})

    assert strategy.ai_assisted == true
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

  test "messages can be appended and listed in order", %{strategy: strategy} do
    {:ok, first} = Strategies.add_message(strategy, :assistant, "What is your True North?")
    {:ok, second} = Strategies.add_message(strategy, :user, "Everyone has a safe home")

    assert [^first, ^second] = Strategies.list_messages(strategy)
  end
end
