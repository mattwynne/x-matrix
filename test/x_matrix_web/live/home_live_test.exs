defmodule XMatrixWeb.HomeLiveTest do
  use XMatrixWeb.ConnCase, async: true

  alias XMatrix.Strategies

  test "lists completed strategies with links to their matrices", %{conn: conn} do
    {:ok, finished} = Strategies.create_draft_strategy(%{title: "Reduce homelessness"})
    {:ok, finished} = Strategies.complete_strategy(finished)

    conn
    |> visit("/")
    |> assert_has("a", text: "Reduce homelessness")
    |> assert_has("a", text: "Start a new strategy")
    |> refute_has("a", text: "View example matrix")
    |> click_link("Reduce homelessness")
    |> assert_path("/strategies/#{finished.id}")
  end

  test "shows resume when a draft exists", %{conn: conn} do
    {:ok, _draft} = Strategies.create_draft_strategy(%{title: "WIP"})

    conn
    |> visit("/")
    |> assert_has("a", text: "Resume interview")
  end

  test "drafts are not listed as completed strategies", %{conn: conn} do
    {:ok, _draft} = Strategies.create_draft_strategy(%{title: "Half-finished draft"})

    conn
    |> visit("/")
    |> refute_has("a", text: "Half-finished draft")
  end
end
