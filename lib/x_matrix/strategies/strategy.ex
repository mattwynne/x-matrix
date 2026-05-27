defmodule XMatrix.Strategies.Strategy do
  use Ecto.Schema
  import Ecto.Changeset

  alias XMatrix.Strategies.{StrategyCorrelation, StrategyElement}

  schema "strategies" do
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:draft, :complete], default: :draft
    field :current_step, :string
    field :ai_assisted, :boolean, default: false

    has_many :elements, StrategyElement
    has_many :correlations, StrategyCorrelation
    has_many :messages, XMatrix.Strategies.StrategyMessage

    timestamps(type: :utc_datetime)
  end

  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [:title, :description, :status, :current_step, :ai_assisted])
    |> validate_required([:title])
  end
end
