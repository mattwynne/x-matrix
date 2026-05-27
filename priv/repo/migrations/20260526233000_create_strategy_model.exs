defmodule XMatrix.Repo.Migrations.CreateStrategyModel do
  use Ecto.Migration

  def change do
    create table(:strategies) do
      add :title, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create table(:strategy_elements) do
      add :strategy_id, references(:strategies, on_delete: :delete_all), null: false
      add :element_type, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:strategy_elements, [:strategy_id])
    create index(:strategy_elements, [:strategy_id, :element_type])

    create table(:strategy_correlations) do
      add :strategy_id, references(:strategies, on_delete: :delete_all), null: false
      add :source_element_id, references(:strategy_elements, on_delete: :delete_all), null: false
      add :target_element_id, references(:strategy_elements, on_delete: :delete_all), null: false
      add :strength, :string, null: false
      add :rationale, :text

      timestamps(type: :utc_datetime)
    end

    create index(:strategy_correlations, [:strategy_id])
    create index(:strategy_correlations, [:source_element_id])
    create index(:strategy_correlations, [:target_element_id])
  end
end
