defmodule XMatrixWeb.HomeLiveTest do
  use XMatrixWeb.ConnCase, async: true

  alias XMatrix.Strategies

  test "shows the three choices and links to the example matrix", %{conn: conn} do
    {:ok, example} = Strategies.create_draft_strategy(%{title: "Example"})
    {:ok, _} = Strategies.complete_strategy(example)

    conn
    |> visit("/")
    |> assert_has("a", text: "View example matrix")
    |> assert_has("a", text: "Start interview")
    |> refute_has("a", text: "Resume interview")
  end

  test "shows resume when a draft exists", %{conn: conn} do
    {:ok, _draft} = Strategies.create_draft_strategy(%{title: "WIP"})

    conn
    |> visit("/")
    |> assert_has("a", text: "Resume interview")
  end
end
