defmodule SecopService.Repo.Migrations.CreateSecNodes do
  use Ecto.Migration

  def change do
    create table(:sec_nodes, primary_key: false) do
      add :uuid, :uuid, primary_key: true
      add :equipment_id, :string, null: false
      add :host, :string, null: false
      add :port, :integer, null: false
      add :description, :text
      add :firmware, :string
      add :implementor, :string
      add :timeout, :integer
      # JSONB in PostgreSQL
      add :describe_message, :map
      # JSONB in PostgreSQL
      add :custom_properties, :map

      timestamps()
    end

    create index(:sec_nodes, [:equipment_id])
  end
end
