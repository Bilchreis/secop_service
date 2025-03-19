defmodule SecopService.Sec_Nodes do
  import Ecto.Query
  alias SecopService.Repo
  alias SecopService.Sec_Nodes.{Parameter, ParameterValue}

  # Parse and store a raw SECoP message
  def create_parameter_value_from_secop_message(parameter, secop_message) do
    case parse_secop_message(secop_message) do
      {:ok, raw_value, qualifiers} ->
        # Use timestamp from qualifiers if available, with microsecond precision
        timestamp = case Map.get(qualifiers, "t") do
          nil ->
            DateTime.utc_now()

          t when is_float(t) ->
            # Convert float timestamp to DateTime with microsecond precision
            # Extract seconds and microseconds parts
            seconds = trunc(t)
            microseconds = trunc((t - seconds) * 1_000_000)

            # Format with microsecond precision
            {:ok, datetime} = DateTime.from_unix(seconds, :second)
            %{datetime | microsecond: {microseconds, 6}}

          t when is_integer(t) ->
            DateTime.from_unix!(t, :second)
        end

        create_parameter_value(parameter, raw_value, timestamp, qualifiers)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Parse the SECoP message format [value, {qualifiers}]
  defp parse_secop_message(secop_message) do
    try do
      case secop_message do
        [value, qualifiers] when is_map(qualifiers) ->
          {:ok, value, qualifiers}

        [value] ->
          # Message with just a value, no qualifiers
          {:ok, value, %{}}

        value when not is_list(value) ->
          # Simple value without the list format
          {:ok, value, %{}}

        _ ->
          {:error, "Invalid SECoP message format"}
      end
    rescue
      e -> {:error, "Error parsing SECoP message: #{inspect(e)}"}
    end
  end

  # Create parameter value from components
  def create_parameter_value(parameter, raw_value, timestamp \\ nil, qualifiers \\ %{}) do
    timestamp = timestamp || DateTime.utc_now()

    ParameterValue.create_with_parameter(raw_value, parameter, timestamp, qualifiers)
    |> Repo.insert()
  end

  def get_recent_values(parameter_id, limit \\ 100) do
    ParameterValue
    |> where(parameter_id: ^parameter_id)
    |> order_by(desc: :timestamp)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_values_in_timerange(parameter_id, start_time, end_time) do
    ParameterValue
    |> where(parameter_id: ^parameter_id)
    |> where([v], v.timestamp >= ^start_time)
    |> where([v], v.timestamp <= ^end_time)
    |> order_by(asc: :timestamp)
    |> Repo.all()
  end

  # Helper function to get formatted display values
  def get_formatted_values(parameter_id, limit \\ 100) do
    parameter = Repo.get!(Parameter, parameter_id)

    values = get_recent_values(parameter_id, limit)

    Enum.map(values, fn value ->
      %{
        display_value: ParameterValue.get_display_value(value, parameter),
        raw_value: ParameterValue.get_raw_value(value, parameter),
        timestamp: value.timestamp,
        qualifiers: value.qualifiers
      }
    end)
  end

  # Get value with error/uncertainty if available
  def get_value_with_uncertainty(parameter_value) do
    raw_value = ParameterValue.get_raw_value(parameter_value, parameter_value.parameter)

    case Map.get(parameter_value.qualifiers, "e") do
      nil ->
        %{value: raw_value}
      uncertainty ->
        %{value: raw_value, uncertainty: uncertainty}
    end
  end
end
