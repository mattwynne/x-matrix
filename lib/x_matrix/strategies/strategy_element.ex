defmodule XMatrix.Strategies.StrategyElement do
  use Ecto.Schema
  import Ecto.Changeset

  alias XMatrix.Strategies.{Strategy, StrategyCorrelation}

  @types [:true_north, :aspiration, :strategy, :evidence, :tactic]

  schema "strategy_elements" do
    field :element_type, Ecto.Enum, values: @types
    field :title, :string
    field :description, :string
    field :position, :integer, default: 0

    belongs_to :strategy, Strategy
    has_many :source_correlations, StrategyCorrelation, foreign_key: :source_element_id
    has_many :target_correlations, StrategyCorrelation, foreign_key: :target_element_id

    timestamps(type: :utc_datetime)
  end

  def types, do: @types

  def changeset(element, attrs) do
    element
    |> cast(attrs, [:strategy_id, :element_type, :title, :description, :position])
    |> validate_required([:strategy_id, :element_type, :title, :position])
  end
end
