defmodule XMatrix.Strategies.StrategyCorrelation do
  use Ecto.Schema
  import Ecto.Changeset

  alias XMatrix.Strategies.{Strategy, StrategyElement}

  @strengths [:none, :weak, :medium, :strong]

  schema "strategy_correlations" do
    field :strength, Ecto.Enum, values: @strengths
    field :rationale, :string

    belongs_to :strategy, Strategy
    belongs_to :source_element, StrategyElement
    belongs_to :target_element, StrategyElement

    timestamps(type: :utc_datetime)
  end

  def strengths, do: @strengths

  def changeset(correlation, attrs) do
    correlation
    |> cast(attrs, [:strategy_id, :source_element_id, :target_element_id, :strength, :rationale])
    |> validate_required([:strategy_id, :source_element_id, :target_element_id, :strength])
  end
end
