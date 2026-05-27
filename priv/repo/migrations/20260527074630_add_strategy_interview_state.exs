defmodule XMatrix.Repo.Migrations.AddStrategyInterviewState do
  use Ecto.Migration

  def change do
    alter table(:strategies) do
      add :status, :string, null: false, default: "draft"
      add :current_step, :string
    end

    # Existing/seeded rows are finished strategies, not drafts.
    execute(
      "UPDATE strategies SET status = 'complete'",
      "UPDATE strategies SET status = 'draft'"
    )
  end
end
