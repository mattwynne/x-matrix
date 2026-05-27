defmodule XMatrix.Strategies.Strategy do
  use Ecto.Schema
  import Ecto.Changeset

  alias XMatrix.Strategies.{StrategyCorrelation, StrategyElement}

  schema "strategies" do
    field :title, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:draft, :complete], default: :draft
    field :current_step, :string

    has_many :elements, StrategyElement
    has_many :correlations, StrategyCorrelation

    timestamps(type: :utc_datetime)
  end

  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [:title, :description, :status, :current_step])
    |> validate_required([:title])
  end
end
