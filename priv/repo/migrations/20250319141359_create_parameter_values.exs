defmodule SecopService.Repo.Migrations.CreateParameterValues do
  use Ecto.Migration

  def change do
    create table(:parameter_values) do
      # JSONB in PostgreSQL
      add :value, :map
      add :timestamp, :utc_datetime_usec, null: false
      # JSONB in PostgreSQL
      add :qualifiers, :map
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:parameter_values, [:parameter_id])
    create index(:parameter_values, [:timestamp])

    # Change ID to BigInt
    execute "ALTER TABLE parameter_values ALTER COLUMN id TYPE BIGINT"
  end
end
