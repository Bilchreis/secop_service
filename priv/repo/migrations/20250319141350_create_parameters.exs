defmodule SecopService.Repo.Migrations.CreateParameters do
  use Ecto.Migration

  def change do
    create table(:parameters) do
      add :name, :string, null: false
      # JSONB in PostgreSQL
      add :data_info, :map
      add :readonly, :boolean, default: false
      add :description, :string
      add :module_id, references(:modules, on_delete: :delete_all), null: false
      # JSONB in PostgreSQL
      add :properties, :map

      timestamps()
    end

    create index(:parameters, [:module_id])
    create unique_index(:parameters, [:module_id, :name])
  end
end
