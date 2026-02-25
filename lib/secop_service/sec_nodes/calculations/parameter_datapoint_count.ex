defmodule SecopService.SecNodes.Calculations.ParameterDatapointCount do
  @moduledoc """
  Calculation to compute datapoint count for parameters.

  Each parameter stores values in exactly one `parameter_values_*` table,
  derived from its `datainfo` type. This calculation counts rows only in that
  active table.
  """

  use Ash.Resource.Calculation

  alias SecopService.SecNodes.ParameterValue

  @table_by_storage_type %{
    int: "parameter_values_int",
    double: "parameter_values_double",
    bool: "parameter_values_bool",
    string: "parameter_values_string",
    array_int: "parameter_values_array_int",
    array_double: "parameter_values_array_double",
    array_bool: "parameter_values_array_bool",
    array_string: "parameter_values_array_string",
    json: "parameter_values_json"
  }

  @impl true
  def load(_query, _opts, _context) do
    [:datainfo]
  end

  @impl true
  def calculate(parameters, _opts, _context) do
    counts_by_parameter_id =
      parameters
      |> Enum.group_by(fn parameter ->
        parameter
        |> ParameterValue.get_storage_type()
        |> then(&Map.fetch!(@table_by_storage_type, &1))
      end)
      |> Enum.reduce(%{}, fn {table_name, table_parameters}, acc ->
        parameter_ids = Enum.map(table_parameters, & &1.id)
        table_counts = query_counts_for_table(table_name, parameter_ids)
        Map.merge(acc, table_counts)
      end)

    Enum.map(parameters, fn parameter ->
      Map.get(counts_by_parameter_id, parameter.id, 0)
    end)
  end

  defp query_counts_for_table(_table_name, []), do: %{}

  defp query_counts_for_table(table_name, parameter_ids) do
    query =
      """
      SELECT parameter_id, COUNT(*)
      FROM #{table_name}
      WHERE parameter_id = ANY($1)
      GROUP BY parameter_id
      """

    case Ecto.Adapters.SQL.query(SecopService.Repo, query, [parameter_ids]) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [parameter_id, count] ->
          {parameter_id, count}
        end)

      {:error, _reason} ->
        %{}
    end
  end
end
