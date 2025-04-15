defmodule SecopService.Repo.Migrations.CreateParameters do
  use Ecto.Migration

  def change do
    create table(:parameters) do
      add :name, :string, null: false
      # JSONB in PostgreSQL
      add :datainfo, :map
      add :readonly, :boolean, default: false
      add :description, :text
      add :module_id, references(:modules, on_delete: :delete_all), null: false
      # JSONB in PostgreSQL
      add :custom_properties, :map

      # Optional properties:
      add :group, :string
      add :visibility, :string
      add :meaning, :map
      add :checkable, :boolean

      timestamps()
    end

    create index(:parameters, [:module_id])
    create unique_index(:parameters, [:module_id, :name])
  end
end
