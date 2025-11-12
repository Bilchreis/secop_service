defmodule SecopService.Repo.Migrations.CreateTypedParameterValues do
  use Ecto.Migration

  def change do
    # Drop old table if migrating from existing setup
    drop_if_exists table(:parameter_values)

    # Atomic types
    create table(:parameter_values_int) do
      add :value, :bigint, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :qualifiers, :map
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false
      timestamps()
    end

    create table(:parameter_values_double) do
      add :value, :float, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :qualifiers, :map
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false
      timestamps()
    end

    create table(:parameter_values_bool) do
      add :value, :boolean, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :qualifiers, :map
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false
      timestamps()
    end

    create table(:parameter_values_string) do
      add :value, :text, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :qualifiers, :map
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false
      timestamps()
    end

    # 1D Arrays of atomic types (using PostgreSQL array columns)
    create table(:parameter_values_array_int) do
      add :value, {:array, :bigint}, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :qualifiers, :map
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false
      timestamps()
    end

    create table(:parameter_values_array_double) do
      add :value, {:array, :float}, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :qualifiers, :map
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false
      timestamps()
    end

    create table(:parameter_values_array_bool) do
      add :value, {:array, :boolean}, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :qualifiers, :map
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false
      timestamps()
    end

    create table(:parameter_values_array_string) do
      add :value, {:array, :text}, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :qualifiers, :map
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false
      timestamps()
    end

    # Complex/nested types (struct, tuple, nested arrays, blob, matrix)
    create table(:parameter_values_json) do
      # JSONB
      add :value, :map, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :qualifiers, :map
      add :parameter_id, references(:parameters, on_delete: :delete_all), null: false
      timestamps()
    end

    # Indexes for all tables
    for table <- [
          :parameter_values_int,
          :parameter_values_double,
          :parameter_values_bool,
          :parameter_values_string,
          :parameter_values_array_int,
          :parameter_values_array_double,
          :parameter_values_array_bool,
          :parameter_values_array_string,
          :parameter_values_json
        ] do
      create index(table, [:parameter_id, :timestamp])
      create index(table, [:timestamp])
    end

    # Optional: GIN index for JSONB queries
    create index(:parameter_values_json, [:value], using: :gin)
  end
end
