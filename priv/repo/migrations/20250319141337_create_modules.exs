defmodule SecopService.Repo.Migrations.CreateModules do
  use Ecto.Migration

  def change do
    create table(:modules) do
      add :name, :string, null: false
      add :description, :string
      add :interface_classes, {:array, :string}
      add :properties, :map  # JSONB in PostgreSQL
      add :sec_node_id, references(:sec_nodes, column: :uuid, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:modules, [:sec_node_id])
    create unique_index(:modules, [:sec_node_id, :name])
  end
end
