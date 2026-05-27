defmodule XMatrix.Repo.Migrations.AddChatInterviewState do
  use Ecto.Migration

  def change do
    alter table(:strategies) do
      add :ai_assisted, :boolean, null: false, default: false
    end

    create table(:strategy_messages) do
      add :strategy_id, references(:strategies, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:strategy_messages, [:strategy_id, :inserted_at, :id])
  end
end
