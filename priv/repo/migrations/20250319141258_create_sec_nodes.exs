defmodule SecopService.Repo.Migrations.CreateSecNodes do
  use Ecto.Migration

  def change do
    create table(:sec_nodes, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :equipment_id, :string, null: false
      add :host, :string, null: false
      add :port, :integer, null: false
      add :description, :string
      add :describe_message, :map  # JSONB in PostgreSQL
      add :properties, :map  # JSONB in PostgreSQL

      timestamps()
    end

    create unique_index(:sec_nodes, [:host, :port])
    create index(:sec_nodes, [:equipment_id])
  end
end
