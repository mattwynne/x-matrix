defmodule XMatrix.Strategies.StrategyMessage do
  use Ecto.Schema
  import Ecto.Changeset

  alias XMatrix.Strategies.Strategy

  schema "strategy_messages" do
    field :role, Ecto.Enum, values: [:assistant, :user]
    field :content, :string

    belongs_to :strategy, Strategy

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:strategy_id, :role, :content])
    |> validate_required([:strategy_id, :role, :content])
  end
end
