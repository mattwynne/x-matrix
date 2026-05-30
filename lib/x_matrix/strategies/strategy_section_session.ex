defmodule XMatrix.Strategies.StrategySectionSession do
  use Ecto.Schema
  import Ecto.Changeset

  alias XMatrix.Strategies.Strategy

  @sections [:true_north]

  schema "strategy_section_sessions" do
    field :section, Ecto.Enum, values: @sections
    field :state, :map, default: %{}

    belongs_to :strategy, Strategy

    timestamps(type: :utc_datetime)
  end

  def sections, do: @sections

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:strategy_id, :section, :state])
    |> validate_required([:strategy_id, :section, :state])
    |> unique_constraint([:strategy_id, :section])
  end
end
