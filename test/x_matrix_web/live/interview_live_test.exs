defmodule XMatrixWeb.InterviewLiveTest do
  use XMatrixWeb.ConnCase, async: true

  alias XMatrix.Strategies

  test "starting an interview creates a draft and opens the welcome screen", %{conn: conn} do
    conn
    |> visit("/interview")
    |> assert_has("h1", text: "Let's build your strategy")

    assert Strategies.get_resumable_draft() != nil
  end

  test "the welcome screen has no Back button", %{conn: conn} do
    conn
    |> visit("/interview")
    |> refute_has("button", text: "Back")
  end

  test "saving the name moves on to True North", %{conn: conn} do
    conn
    |> visit("/interview")
    |> click_button("Let's begin")
    |> fill_in("Strategy name", with: "Reduce homelessness")
    |> click_button("Next")
    |> assert_has("h1", text: "What is your True North?")
  end

  test "an element section captures a statement then a why", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "S", current_step: "elem:add:aspiration"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> click_button("+ Add aspiration")
    |> fill_in("New aspiration", with: "Reduce rough sleeping")
    |> click_button("Next")
    |> assert_has("h1", text: "Why does this aspiration matter?")
    |> fill_in("Why this matters", with: "It is the sharpest end of the crisis")
    |> click_button("Save")
    |> assert_has("li", text: "Reduce rough sleeping")
    |> assert_has("li", text: "It is the sharpest end of the crisis")

    [aspiration] = Strategies.elements_by_type(Strategies.get_strategy!(strategy.id), :aspiration)
    assert aspiration.title == "Reduce rough sleeping"
    assert aspiration.description == "It is the sharpest end of the crisis"
  end

  test "an item can be removed from the hub", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "S", current_step: "elem:add:tactic"})

    {:ok, _} = Strategies.add_element(strategy, %{element_type: :tactic, title: "Doomed tactic"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("li", text: "Doomed tactic")
    |> click_button("Remove")
    |> refute_has("li", text: "Doomed tactic")
  end

  test "the strategy section advises even-over phrasing", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "S", current_step: "elem:intro:strategy"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("p", text: "even over")
  end

  test "a correlation source rates each target and saves", %{conn: conn} do
    {:ok, strategy} = Strategies.create_draft_strategy(%{title: "S"})
    {:ok, strat} = Strategies.add_element(strategy, %{element_type: :strategy, title: "Strat A"})
    {:ok, asp} = Strategies.add_element(strategy, %{element_type: :aspiration, title: "Asp A"})
    {:ok, _} = Strategies.set_step(strategy, "corr:src:strategy_aspiration:#{strat.id}")

    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("p", text: "Strat A")
    |> select("Asp A", option: "Strong")
    |> click_button("Next")

    reloaded = Strategies.get_strategy!(strategy.id)
    assert [corr] = reloaded.correlations
    assert corr.strength == :strong
    assert corr.source_element_id == strat.id
    assert corr.target_element_id == asp.id
  end
end
