defmodule XMatrix.Repo.Migrations.CreateStrategySectionSessions do
  use Ecto.Migration

  def change do
    create table(:strategy_section_sessions) do
      add :strategy_id, references(:strategies, on_delete: :delete_all), null: false
      add :section, :string, null: false
      add :state, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:strategy_section_sessions, [:strategy_id, :section])
  end
end
