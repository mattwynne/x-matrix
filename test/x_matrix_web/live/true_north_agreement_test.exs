defmodule XMatrixWeb.TrueNorthAgreementTest do
  use XMatrixWeb.ConnCase, async: false

  alias XMatrix.Strategies

  setup do
    previous_key = Application.get_env(:x_matrix, :openrouter_api_key)
    Application.put_env(:x_matrix, :openrouter_api_key, nil)

    on_exit(fn -> Application.put_env(:x_matrix, :openrouter_api_key, previous_key) end)
  end

  test "chatting in true north does not save until a candidate is submitted", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:true_north",
        ai_assisted: false
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer or feedback", with: "Everyone has a home")
    |> click_button("Send")
    |> assert_has("#true-north-candidates", text: "Everyone has a home")
    |> refute_has("#emerging-matrix", text: "Everyone has a home")

    assert Strategies.elements_by_type(Strategies.get_strategy!(strategy.id), :true_north) == []
  end

  test "submitting a candidate creates true north and advances to aspirations", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:true_north",
        ai_assisted: false
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer or feedback", with: "Everyone has a home")
    |> click_button("Send")
    |> click_button(
      "#true-north-candidates article:first-of-type button",
      "Submit this True North"
    )
    |> assert_has("#true-north-agreed")
    |> assert_has("h1", text: "You have a True North")
    |> assert_has("div", text: "Everyone has a home")
    |> click_button("Continue to Aspirations")
    |> assert_has("h1", text: "Conversational interview")
    |> assert_has("#taste-progress", text: "Aspirations")
    |> assert_has("#true-north-inline-confirmation", text: "Everyone has a home")
    |> assert_has("#emerging-matrix", text: "Everyone has a home")

    reloaded = Strategies.get_strategy!(strategy.id)
    assert reloaded.current_step == "chat:aspiration"
    assert [true_north] = Strategies.elements_by_type(reloaded, :true_north)
    assert true_north.title == "Everyone has a home"
  end

  test "editing a candidate before submit saves the edited statement", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:true_north",
        ai_assisted: false
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer or feedback", with: "Everyone has a home")
    |> click_button("Send")
    |> click_button(
      "#true-north-candidates article:first-of-type button",
      "Edit before submitting"
    )
    |> fill_in("Statement", with: "No one sleeps rough")
    |> fill_in("Explanation", with: "A safe home is the baseline for everyone.")
    |> click_button("Submit edited True North")
    |> assert_has("#true-north-agreed", text: "No one sleeps rough")

    [true_north] = Strategies.elements_by_type(Strategies.get_strategy!(strategy.id), :true_north)
    assert true_north.title == "No one sleeps rough"
    assert true_north.description == "A safe home is the baseline for everyone."
  end

  test "candidates are restored when returning to true north", %{conn: conn} do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:true_north",
        ai_assisted: false
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer or feedback", with: "Everyone has a home")
    |> click_button("Send")
    |> assert_has("#true-north-candidates", text: "Everyone has a home")

    conn
    |> visit("/interview/#{strategy.id}")
    |> assert_has("#true-north-candidates", text: "Everyone has a home")
    |> assert_has("#interview-transcript", text: "Everyone has a home")
  end

  test "resubmitting true north updates the existing element and leaves downstream work", %{
    conn: conn
  } do
    {:ok, strategy} =
      Strategies.create_draft_strategy(%{
        title: "S",
        current_step: "chat:true_north",
        ai_assisted: false
      })

    {:ok, _aspiration} =
      Strategies.add_element(strategy, %{
        element_type: :aspiration,
        title: "More stable tenancies"
      })

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer or feedback", with: "Everyone has a home")
    |> click_button("Send")
    |> click_button(
      "#true-north-candidates article:first-of-type button",
      "Submit this True North"
    )

    {:ok, strategy} =
      Strategies.set_step(Strategies.get_strategy!(strategy.id), "chat:true_north")

    conn
    |> visit("/interview/#{strategy.id}")
    |> fill_in("Your answer or feedback", with: "No one sleeps rough")
    |> click_button("Send")
    |> click_button(
      "#true-north-candidates article:first-of-type button",
      "Submit this True North"
    )
    |> assert_has("#true-north-agreed", text: "No one sleeps rough")
    |> click_button("Continue to Aspirations")
    |> assert_has("#emerging-matrix", text: "No one sleeps rough")
    |> assert_has("#emerging-matrix", text: "More stable tenancies")

    reloaded = Strategies.get_strategy!(strategy.id)
    assert Enum.count(Strategies.elements_by_type(reloaded, :true_north)) == 1
    assert Enum.count(Strategies.elements_by_type(reloaded, :aspiration)) == 1
    assert [true_north] = Strategies.elements_by_type(reloaded, :true_north)
    assert true_north.title == "No one sleeps rough"
    assert strategy.status == :draft
  end
end
