defmodule XMatrixWeb.XMatrixLiveTest do
  use XMatrixWeb.ConnCase, async: true

  alias XMatrix.Repo
  alias XMatrix.Strategies.{Strategy, StrategyCorrelation, StrategyElement}

  setup do
    strategy =
      %Strategy{}
      |> Strategy.changeset(%{
        title: "Multi-agency homelessness reduction strategy",
        description: "A seeded read-only strategy for reducing homelessness."
      })
      |> Repo.insert!()

    elements =
      [
        {:true_north, "Everyone has a safe, stable place to call home"},
        {:aspiration, "Reduce rough sleeping by 50%"},
        {:strategy, "Intervene before crisis"},
        {:evidence, "Median days from referral to stable housing"},
        {:tactic, "Shared by-name case conference"}
      ]
      |> Enum.with_index(1)
      |> Enum.map(fn {{type, title}, position} ->
        element =
          %StrategyElement{}
          |> StrategyElement.changeset(%{
            strategy_id: strategy.id,
            element_type: type,
            title: title,
            description: "#{title} description",
            position: position
          })
          |> Repo.insert!()

        {type, element}
      end)
      |> Map.new()

    %StrategyCorrelation{}
    |> StrategyCorrelation.changeset(%{
      strategy_id: strategy.id,
      source_element_id: elements.strategy.id,
      target_element_id: elements.aspiration.id,
      strength: :strong,
      rationale: "Directly supports the aspiration."
    })
    |> Repo.insert!()

    %StrategyCorrelation{}
    |> StrategyCorrelation.changeset(%{
      strategy_id: strategy.id,
      source_element_id: elements.tactic.id,
      target_element_id: elements.evidence.id,
      strength: :weak,
      rationale: "A secondary leading indicator."
    })
    |> Repo.insert!()

    %{strategy: strategy}
  end

  test "renders the read-only X-Matrix", %{conn: conn, strategy: strategy} do
    conn
    |> visit("/strategies/#{strategy.id}")
    |> assert_has("h1", text: "Multi-agency homelessness reduction strategy")
    |> assert_has("h2", text: "True North")
    |> assert_has("span", text: "Strategies")
    |> assert_has("span", text: "Tactics")
    |> assert_has("span", text: "Evidence")
    |> assert_has("span", text: "Aspirations")
    |> assert_has("span", text: "Everyone has a safe, stable place to call home")
    |> assert_has("span", text: "Reduce rough sleeping by 50%")
    |> assert_has("span", text: "Intervene before crisis")
    |> assert_has("span", text: "Median days from referral to stable housing")
    |> assert_has("span", text: "Shared by-name case conference")
    |> assert_has("span.sr-only", text: "strong")
    |> assert_has("span.sr-only", text: "weak")
    |> refute_has("form")
    |> refute_has("button", text: "Edit")
  end
end
