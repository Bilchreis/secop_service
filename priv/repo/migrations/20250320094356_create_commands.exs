defmodule SecopService.Repo.Migrations.CreateCommands do
  use Ecto.Migration

  def change do
    create table(:commands) do
      add :name, :string, null: false
      add :description, :string
      # JSONB in PostgreSQL
      add :datainfo, :map
      add :module_id, references(:modules, on_delete: :delete_all), null: false
      # JSONB in PostgreSQL
      add :custom_properties, :map
      # JSONB in PostgreSQL
      add :argument, :map
      # JSONB in PostgreSQL
      add :result, :map

      # Optional properties:
      add :group, :string
      add :visibility, :string
      add :meaning, :map
      add :checkable, :boolean

      timestamps()
    end

    create index(:commands, [:module_id])
    create unique_index(:commands, [:module_id, :name])
  end
end
