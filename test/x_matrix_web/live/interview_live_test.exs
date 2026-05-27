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

  test "strategy_aspiration step saves a strength per pair", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "S", current_step: "strategy_aspiration"})

    {:ok, strat} = Strategies.add_element(strategy, %{element_type: :strategy, title: "Strat A"})
    {:ok, asp} = Strategies.add_element(strategy, %{element_type: :aspiration, title: "Asp A"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("h1", text: "Strategies → Aspirations")
    |> select("#{strat.title} → #{asp.title}", option: "strong")
    |> click_button("Next")

    reloaded = Strategies.get_strategy!(strategy.id)
    assert [corr] = reloaded.correlations
    assert corr.strength == :strong
    assert corr.source_element_id == strat.id
    assert corr.target_element_id == asp.id
  end

  test "review step finishes and navigates to the matrix", %{conn: conn} do
    {:ok, strategy} = Strategies.create_draft_strategy(%{title: "Done", current_step: "review"})
    {:ok, _} = Strategies.add_element(strategy, %{element_type: :true_north, title: "TN"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> click_button("Finish")
    |> assert_path("/strategies/#{strategy.id}")

    assert Strategies.get_strategy!(strategy.id).status == :complete
  end
end
