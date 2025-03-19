defmodule SecopService.Repo.Migrations.CreateParameters do
  use Ecto.Migration

  def change do
    create table(:parameters) do
      add :name, :string, null: false
      add :data_info, :map  # JSONB in PostgreSQL
      add :readonly, :boolean, default: false
      add :module_id, references(:modules, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:parameters, [:module_id])
    create unique_index(:parameters, [:module_id, :name])
  end
end
