defmodule XMatrixWeb.InterviewFlowTest do
  use XMatrixWeb.ConnCase, async: true

  alias XMatrix.Strategies

  test "build a strategy end to end and land on its matrix", %{conn: conn} do
    session =
      conn
      |> visit("/interview")
      |> fill_in("Your answer", with: "Everyone has a safe home")
      |> click_button("Send")
      |> click_button("Move on")
      |> fill_in("Your answer", with: "Reduce rough sleeping")
      |> click_button("Send")
      |> click_button("Move on")
      |> fill_in("Your answer", with: "Prevention even over relief")
      |> click_button("Send")
      |> click_button("Move on")
      |> fill_in("Your answer", with: "Days from referral to housing")
      |> click_button("Send")
      |> click_button("Move on")
      |> fill_in("Your answer", with: "Shared by-name case list")
      |> click_button("Send")
      |> click_button("Move on")
      # strategies -> aspirations
      |> click_button("Continue")
      |> select("Reduce rough sleeping", option: "Strong")
      |> click_button("Next")
      # evidence -> aspirations
      |> click_button("Continue")
      |> select("Reduce rough sleeping", option: "Medium")
      |> click_button("Next")
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
    |> assert_has("h2", text: "True North")
    |> assert_has("span", text: "Reduce rough sleeping")
    |> assert_has("span", text: "Prevention even over relief")
    |> assert_has("span", text: "Days from referral to housing")
    |> assert_has("span", text: "Shared by-name case list")
    |> assert_has("span.sr-only", text: "strong")
  end

  test "resume reopens at the saved chat stage with transcript and prior data", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "WIP", current_step: "chat:strategy"})

    {:ok, _} = Strategies.add_message(strategy, :user, "Earlier thought")

    {:ok, _} =
      Strategies.add_element(strategy, %{element_type: :strategy, title: "Kept strategy"})

    conn
    |> visit("/")
    |> click_link("Resume interview")
    |> assert_has("#taste-progress", text: "Strategies")
    |> assert_has("#interview-transcript", text: "Earlier thought")
    |> assert_has("#emerging-matrix", text: "Kept strategy")
  end

  test "move on enforces TASTE order before relationships", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "WIP", current_step: "chat:strategy"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> click_button("Move on")
    |> assert_has("#taste-progress", text: "Evidence")
    |> refute_has("h1", text: "Tactics → Strategies")
  end

  test "entered data persists across a reload mid-interview", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{title: "WIP", current_step: "chat:aspiration"})

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer", with: "Persisted aspiration")
    |> click_button("Send")

    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("#emerging-matrix", text: "Persisted aspiration")
  end
end
