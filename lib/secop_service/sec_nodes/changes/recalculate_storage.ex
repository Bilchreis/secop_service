defmodule SecopService.SecNodes.Changes.RecalculateStorage do
  @moduledoc """
  Change to calculate and update storage metrics (datapoint count and disk size)
  for a given SecNode by querying across all parameter value tables.

  This change is designed to be resilient - if calculations fail, it logs the error
  but allows the changeset to proceed so other changes (like state transitions) aren't blocked.
  """

  use Ash.Resource.Change
  require Ash.Query
  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    node = changeset.data
    repo = SecopService.Repo

    Logger.info("Calculating storage metrics for node #{node.uuid}...")

    # Calculate storage metrics, but don't fail the changeset if calculation fails
    case calculate_storage_metrics_safe(node.uuid, repo) do
      {:ok, {datapoint_count, disk_size_bytes}} ->
        changeset
        |> Ash.Changeset.change_attribute(:datapoint_count, datapoint_count)
        |> Ash.Changeset.change_attribute(:disk_size_bytes, disk_size_bytes)

      {:error, reason} ->
        Logger.warning(
          "Failed to calculate storage metrics for node #{node.uuid}: #{inspect(reason)}"
        )

        # Return changeset unchanged - allow other changes to proceed
        changeset
    end
  end

  @doc """
  Calculate total datapoint count and disk size across all parameter value tables
  for a given node UUID. Returns {:ok, {datapoint_count, disk_size_bytes}} or {:error, reason}.
  """
  def calculate_storage_metrics_safe(node_uuid, repo) do
    try do
      {datapoint_count, disk_size_bytes} = calculate_storage_metrics(node_uuid, repo)
      {:ok, {datapoint_count, disk_size_bytes}}
    rescue
      e ->
        {:error, Exception.message(e)}

      e in _ ->
        {:error, inspect(e)}
    catch
      :error, reason ->
        {:error, inspect(reason)}
    end
  end

  @doc """
  Calculate total datapoint count and disk size across all parameter value tables
  for a given node UUID.

  Returns {datapoint_count, disk_size_bytes}
  """
  def calculate_storage_metrics(node_uuid, repo) when is_binary(node_uuid) do
    # Convert string UUID to binary if needed
    node_uuid_binary =
      if byte_size(node_uuid) == 16 do
        node_uuid
      else
        {:ok, binary} = Ecto.UUID.dump(node_uuid)
        binary
      end

    # Query to get all parameter IDs for this node
    parameter_ids_query = """
    SELECT p.id
    FROM parameters p
    INNER JOIN modules m ON p.module_id = m.id
    WHERE m.sec_node_id = $1
    """

    {:ok, result} = Ecto.Adapters.SQL.query(repo, parameter_ids_query, [node_uuid_binary])
    parameter_ids = Enum.map(result.rows, &List.first/1)

    if Enum.empty?(parameter_ids) do
      {0, 0}
    else
      datapoint_count = count_datapoints(parameter_ids, repo)
      disk_size_bytes = calculate_disk_size(parameter_ids, repo)
      {datapoint_count, disk_size_bytes}
    end
  end

  defp count_datapoints(parameter_ids, repo) do
    # Count rows across all parameter value tables
    tables = [
      "parameter_values_int",
      "parameter_values_double",
      "parameter_values_bool",
      "parameter_values_string",
      "parameter_values_array_int",
      "parameter_values_array_double",
      "parameter_values_array_bool",
      "parameter_values_array_string",
      "parameter_values_json"
    ]

    total_count =
      Enum.reduce(tables, 0, fn table, acc ->
        query = """
        SELECT COUNT(*) FROM #{table}
        WHERE parameter_id = ANY($1)
        """

        case Ecto.Adapters.SQL.query(repo, query, [parameter_ids]) do
          {:ok, result} ->
            count = result.rows |> List.first() |> List.first()
            acc + (count || 0)

          {:error, _} ->
            acc
        end
      end)

    total_count
  end

  defp calculate_disk_size(parameter_ids, repo) do
    # Calculate disk size across all parameter value tables using pg_total_relation_size
    tables = [
      "parameter_values_int",
      "parameter_values_double",
      "parameter_values_bool",
      "parameter_values_string",
      "parameter_values_array_int",
      "parameter_values_array_double",
      "parameter_values_array_bool",
      "parameter_values_array_string",
      "parameter_values_json"
    ]

    # Build a query that sums the relation sizes for tables that have data for our parameters
    table_checks =
      tables
      |> Enum.map(fn table ->
        "CASE WHEN EXISTS(SELECT 1 FROM #{table} WHERE parameter_id = ANY($1)) THEN pg_total_relation_size('#{table}'::regclass) ELSE 0 END"
      end)
      |> Enum.join(" + ")

    query = "SELECT #{table_checks}"

    case Ecto.Adapters.SQL.query(repo, query, [parameter_ids]) do
      {:ok, result} ->
        result.rows |> List.first() |> List.first() || 0

      {:error, _} ->
        0
    end
  end
end
