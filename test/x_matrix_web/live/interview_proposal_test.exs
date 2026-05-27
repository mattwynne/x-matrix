defmodule XMatrixWeb.InterviewProposalTest do
  use XMatrixWeb.ConnCase, async: false

  alias XMatrix.Strategies

  setup do
    previous_adapter = Application.get_env(:x_matrix, :llm_adapter)
    previous_key = Application.get_env(:x_matrix, :anthropic_api_key)

    Application.put_env(:x_matrix, :llm_adapter, XMatrix.TestLLM.ProposingAdapter)
    Application.put_env(:x_matrix, :anthropic_api_key, "test-key")

    on_exit(fn ->
      Application.put_env(:x_matrix, :llm_adapter, previous_adapter)
      Application.put_env(:x_matrix, :anthropic_api_key, previous_key)
    end)
  end

  test "proposal cards can be added", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:aspiration",
        ai_assisted: true
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer", with: "Help me")
    |> click_button("Send")
    |> assert_has("div", text: "Suggested item")
    |> click_button("Add")
    |> assert_has("#emerging-matrix", text: "Suggested item")

    [aspiration] = Strategies.elements_by_type(Strategies.get_strategy!(strategy.id), :aspiration)
    assert aspiration.title == "Suggested item"
  end

  test "proposal cards can be dismissed without persisting", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:aspiration",
        ai_assisted: true
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer", with: "Help me")
    |> click_button("Send")
    |> click_button("Dismiss")
    |> refute_has("#emerging-matrix", text: "Suggested item")

    assert Strategies.elements_by_type(Strategies.get_strategy!(strategy.id), :aspiration) == []
  end

  test "proposal cards can be edited before adding", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:aspiration",
        ai_assisted: true
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer", with: "Help me")
    |> click_button("Send")
    |> click_button("Edit")
    |> fill_in("Title", with: "Edited suggestion")
    |> click_button("Save and add")
    |> assert_has("#emerging-matrix", text: "Edited suggestion")

    [aspiration] = Strategies.elements_by_type(Strategies.get_strategy!(strategy.id), :aspiration)
    assert aspiration.title == "Edited suggestion"
  end

  test "transient proposals are not restored on resume", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:aspiration",
        ai_assisted: true
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer", with: "Help me")
    |> click_button("Send")
    |> assert_has("#interview-transcript", text: "I have a suggestion.")

    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("#interview-transcript", text: "I have a suggestion.")
    |> refute_has("div", text: "Suggested item")
  end
end
