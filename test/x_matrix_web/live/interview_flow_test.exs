defmodule XMatrixWeb.InterviewFlowTest do
  use XMatrixWeb.ConnCase, async: true

  alias XMatrix.Strategies

  test "build a strategy end to end and land on its matrix", %{conn: conn} do
    session =
      conn
      |> visit("/interview")
      |> click_button("Let's begin")
      # name
      |> fill_in("Strategy name", with: "Reduce homelessness")
      |> click_button("Next")
      # true north
      |> fill_in("True North", with: "Everyone has a safe home")
      |> click_button("Next")
      |> fill_in("Why this True North", with: "Housing is a basic right")
      |> click_button("Next")
      # aspirations
      |> click_button("Continue")
      |> click_button("+ Add aspiration")
      |> fill_in("New aspiration", with: "Reduce rough sleeping")
      |> click_button("Next")
      |> fill_in("Why this matters", with: "The sharpest end of the crisis")
      |> click_button("Save")
      |> click_button("Continue")
      # strategies
      |> click_button("Continue")
      |> click_button("+ Add strategy")
      |> fill_in("New strategy", with: "Prevention even over relief")
      |> click_button("Next")
      |> click_button("Skip")
      |> click_button("Continue")
      # strategies -> aspirations
      |> click_button("Continue")
      |> select("Reduce rough sleeping", option: "Strong")
      |> click_button("Next")
      # evidence
      |> click_button("Continue")
      |> click_button("+ Add piece of evidence")
      |> fill_in("New piece of evidence", with: "Days from referral to housing")
      |> click_button("Next")
      |> click_button("Skip")
      |> click_button("Continue")
      # evidence -> aspirations
      |> click_button("Continue")
      |> select("Reduce rough sleeping", option: "Medium")
      |> click_button("Next")
      # tactics
      |> click_button("Continue")
      |> click_button("+ Add tactic")
      |> fill_in("New tactic", with: "Shared by-name case list")
      |> click_button("Next")
      |> click_button("Skip")
      |> click_button("Continue")
      # tactics -> strategies
      |> click_button("Continue")
      |> select("Prevention even over relief", option: "Strong")
      |> click_button("Next")
      # tactics -> evidence
      |> click_button("Continue")
      |> select("Days from referral to housing", option: "Strong")
      |> click_button("Next")

    session
    |> assert_has("h1", text: "You've built your X-Matrix")
    |> click_button("Finish & view matrix")
    |> assert_has("h1", text: "Reduce homelessness")
    |> assert_has("h2", text: "True North")
    |> assert_has("span", text: "Reduce rough sleeping")
    |> assert_has("span", text: "Prevention even over relief")
    |> assert_has("span", text: "Days from referral to housing")
    |> assert_has("span", text: "Shared by-name case list")
    |> assert_has("span.sr-only", text: "strong")
  end

  test "resume reopens at the saved step with prior data", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "WIP", current_step: "elem:add:strategy"})

    {:ok, _} =
      Strategies.add_element(strategy, %{element_type: :strategy, title: "Kept strategy"})

    conn
    |> visit("/")
    |> click_link("Resume interview")
    |> assert_has("h1", text: "Strategies")
    |> assert_has("li", text: "Kept strategy")
  end

  test "tactics cannot be reached before evidence", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "WIP", current_step: "elem:add:strategy"})

    {:ok, _} = Strategies.add_element(strategy, %{element_type: :strategy, title: "S"})
    {:ok, _} = Strategies.add_element(strategy, %{element_type: :aspiration, title: "A"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> click_button("Continue")
    |> assert_has("h1", text: "Strategies → Aspirations")
    |> refute_has("h1", text: "Tactics")
  end

  test "entered data persists across a reload mid-interview", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "WIP", current_step: "elem:add:aspiration"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> click_button("+ Add aspiration")
    |> fill_in("New aspiration", with: "Persisted aspiration")
    |> click_button("Next")
    |> click_button("Skip")

    # A fresh visit simulates a reload; the draft resumes with its data intact.
    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("li", text: "Persisted aspiration")
  end
end
