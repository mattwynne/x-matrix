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
      |> fill_in("Title", with: "Reduce rough sleeping")
      |> click_button("Add")
      |> click_button("Next")
      |> fill_in("Title", with: "Intervene before crisis")
      |> click_button("Add")
      |> click_button("Next")
      |> click_button("Next")
      |> fill_in("Title", with: "Days to stable housing")
      |> click_button("Add")
      |> click_button("Next")
      |> click_button("Next")
      |> fill_in("Title", with: "By-name case conference")
      |> click_button("Add")
      |> click_button("Next")
      |> click_button("Next")
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
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "WIP", current_step: "strategies"})

    {:ok, _} = Strategies.add_element(strategy, %{element_type: :strategy, title: "Kept item"})

    conn
    |> visit("/")
    |> click_link("Resume interview")
    |> assert_has("h1", text: "Strategies")
    |> assert_has("li", text: "Kept item")
  end

  test "tactics cannot be reached before evidence", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "WIP", current_step: "strategies"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> click_button("Next")
    |> assert_has("h1", text: "Strategies → Aspirations")
    |> refute_has("h1", text: "Tactics")
  end

  test "entered data persists across a reload mid-interview", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "WIP", current_step: "aspirations"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Title", with: "Persisted aspiration")
    |> click_button("Add")

    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("li", text: "Persisted aspiration")
  end
end
