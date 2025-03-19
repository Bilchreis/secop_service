defmodule SecopService.Repo.Migrations.CreateParameterValues do
  use Ecto.Migration

  def change do
    create table(:parameter_values) do
      add :value, :map  # JSONB in PostgreSQL
      add :timestamp, :utc_datetime_usec, null: false
      add :qualifiers, :map  # JSONB in PostgreSQL
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:parameter_values, [:parameter_id])
    create index(:parameter_values, [:timestamp])

    # Change ID to BigInt
    execute "ALTER TABLE parameter_values ALTER COLUMN id TYPE BIGINT"

    # For PostgreSQL, create a GIN index for efficient JSONB querying
    execute "CREATE INDEX parameter_values_value_idx ON parameter_values USING GIN (value jsonb_path_ops)",
            "DROP INDEX IF EXISTS parameter_values_value_idx"
    execute "CREATE INDEX parameter_values_qualifiers_idx ON parameter_values USING GIN (qualifiers jsonb_path_ops)",
            "DROP INDEX IF EXISTS parameter_values_qualifiers_idx"
  end
end
