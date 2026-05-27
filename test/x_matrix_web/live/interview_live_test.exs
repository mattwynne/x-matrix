defmodule XMatrixWeb.InterviewLiveTest do
  use XMatrixWeb.ConnCase, async: true

  alias XMatrix.Strategies

  test "starting an interview creates a draft and opens the chat shell", %{conn: conn} do
    conn
    |> visit("/interview")
    |> assert_has("h1", text: "Conversational interview")
    |> assert_has("#interview-transcript")
    |> assert_has("#chat-form")
    |> assert_has("#emerging-matrix")
    |> assert_has("#taste-progress")
    |> assert_has("#ai-toggle")

    assert Strategies.get_resumable_draft() != nil
  end

  test "scripted mode adds typed answers directly to the emerging matrix", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:aspiration",
        ai_assisted: false
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer", with: "Reduce rough sleeping")
    |> click_button("Send")
    |> assert_has("#emerging-matrix", text: "Reduce rough sleeping")

    [aspiration] = Strategies.elements_by_type(Strategies.get_strategy!(strategy.id), :aspiration)
    assert aspiration.title == "Reduce rough sleeping"

    assert Enum.map(Strategies.list_messages(strategy), & &1.role) == [
             :assistant,
             :user,
             :assistant
           ]
  end

  test "AI mode treats free text as chat until Add my answer", %{conn: conn} do
    previous_key = Application.get_env(:x_matrix, :anthropic_api_key)
    Application.put_env(:x_matrix, :anthropic_api_key, "test-key")

    on_exit(fn -> Application.put_env(:x_matrix, :anthropic_api_key, previous_key) end)

    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:aspiration",
        ai_assisted: true
      })

    session =
      conn
      |> visit("/interview/#{strategy.id}")
      |> fill_in("Your answer", with: "Reduce rough sleeping")
      |> click_button("Send")
      |> assert_has("#interview-transcript", text: "Reduce rough sleeping")

    assert Strategies.elements_by_type(Strategies.get_strategy!(strategy.id), :aspiration) == []

    session
    |> click_button("Add my answer")
    |> assert_has("#emerging-matrix", text: "Reduce rough sleeping")

    [aspiration] = Strategies.elements_by_type(Strategies.get_strategy!(strategy.id), :aspiration)
    assert aspiration.title == "Reduce rough sleeping"
  end

  test "AI toggle persists on the draft", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:true_north",
        ai_assisted: false
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> click_button("AI OFF")
    |> assert_has("#ai-toggle", text: "AI ON")

    assert Strategies.get_strategy!(strategy.id).ai_assisted == true
  end

  test "AI on without a key shows fallback notice and behaves like manual entry", %{conn: conn} do
    previous_key = Application.get_env(:x_matrix, :anthropic_api_key)
    Application.put_env(:x_matrix, :anthropic_api_key, nil)

    on_exit(fn -> Application.put_env(:x_matrix, :anthropic_api_key, previous_key) end)

    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:true_north",
        ai_assisted: true
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("div", text: "No Anthropic API key is configured")
    |> fill_in("Your answer", with: "Everyone has a home")
    |> click_button("Send")
    |> assert_has("#emerging-matrix", text: "Everyone has a home")
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
