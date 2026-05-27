defmodule XMatrix.Strategies do
  @moduledoc """
  Strategy context for read-only X-Matrix data.
  """

  import Ecto.Query

  alias XMatrix.Repo
  alias XMatrix.Strategies.Strategy

  def get_seeded_strategy! do
    Strategy
    |> order_by([strategy], asc: strategy.inserted_at, asc: strategy.id)
    |> limit(1)
    |> preload(
      elements:
        ^from(element in XMatrix.Strategies.StrategyElement,
          order_by: [asc: element.position, asc: element.id]
        ),
      correlations:
        ^from(correlation in XMatrix.Strategies.StrategyCorrelation,
          order_by: [asc: correlation.id],
          preload: [:source_element, :target_element]
        )
    )
    |> Repo.one!()
  end

  def elements_by_type(%Strategy{} = strategy, element_type) do
    Enum.filter(strategy.elements, &(&1.element_type == element_type))
  end
end
