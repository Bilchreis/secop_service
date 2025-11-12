defmodule SecopService.Sec_Nodes.ParameterValue do
  alias SecopService.Sec_Nodes.Parameter
  alias SecopService.Sec_Nodes.ParameterValue
  alias ExPrintf
  require Logger

  # Type-specific modules
  @type_modules %{
    int: ParameterValue.Int,
    double: ParameterValue.Double,
    bool: ParameterValue.Bool,
    string: ParameterValue.String,
    array_int: ParameterValue.ArrayInt,
    array_double: ParameterValue.ArrayDouble,
    array_bool: ParameterValue.ArrayBool,
    array_string: ParameterValue.ArrayString,
    json: ParameterValue.Json
  }

  # Determine which schema module and table to use for a parameter
  def get_schema_module(%Parameter{} = parameter) do
    storage_type = get_storage_type(parameter)
    Map.fetch!(@type_modules, storage_type)
  end

  def get_schema_module(storage_type) when is_atom(storage_type) do
    Map.fetch!(@type_modules, storage_type)
  end

  def get_storage_type(%Parameter{} = parameter) do
    case parameter.datainfo["type"] do
      "int" ->
        :int

      "scaled" ->
        :int

      "enum" ->
        :int

      "double" ->
        :double

      "bool" ->
        :bool

      "string" ->
        :string

      "array" ->
        # Check if it's a simple 1D array or nested
        member_type = get_in(parameter.datainfo, ["members", "type"])

        case member_type do
          "int" -> :array_int
          "scaled" -> :array_int
          "enum" -> :array_int
          "double" -> :array_double
          "bool" -> :array_bool
          "string" -> :array_string
          # Nested arrays or arrays of complex types
          _ -> :json
        end

      # Complex types: struct, tuple, blob, matrix, nested arrays
      _ ->
        :json
    end
  end

  # Format timestamp consistently
  defp format_timestamp(timestamp) do
    case timestamp do
      nil ->
        DateTime.utc_now()

      %DateTime{} = dt ->
        dt

      unix_time when is_number(unix_time) ->
        try do
          microseconds = trunc(unix_time * 1_000_000)
          DateTime.from_unix!(microseconds, :microsecond)
        rescue
          ArgumentError ->
            Logger.warning("Invalid Unix timestamp: #{inspect(unix_time)}, using current time")
            DateTime.utc_now()
        end

      _other ->
        Logger.warning("Invalid timestamp format: #{inspect(timestamp)}, using current time")
        DateTime.utc_now()
    end
  end

  # Format value based on parameter type
  defp format_value(raw_value, parameter) do
    case parameter.datainfo["type"] do
      # Atomic types - store directly
      "double" ->
        raw_value

      "int" ->
        raw_value

      "bool" ->
        raw_value

      "string" ->
        raw_value

      # Scaled values - convert to integer for storage
      "scaled" ->
        # SECoP transports scaled as integer, store as-is
        raw_value

      # Enum - store numeric value
      "enum" ->
        raw_value

      # 1D arrays - store directly in array columns
      "array" ->
        member_type = get_in(parameter.datainfo, ["members", "type"])

        case member_type do
          type when type in ["int", "scaled", "enum", "double", "bool", "string"] ->
            # Simple array - store directly
            raw_value

          _ ->
            # Complex/nested array - store as map
            %{type: "array", value: raw_value}
        end

      # Complex types - store as structured data
      type when type in ["struct", "tuple", "blob", "matrix"] ->
        %{type: type, value: raw_value}

      type ->
        Logger.warning("Unknown type #{type}, storing as JSON")
        %{type: type || "unknown", value: raw_value}
    end
  end

  def create_map(raw_value, parameter, timestamp, qualifiers \\ %{}) do
    formatted_timestamp = format_timestamp(timestamp)
    formatted_value = format_value(raw_value, parameter)

    %{
      value: formatted_value,
      timestamp: formatted_timestamp,
      qualifiers: qualifiers,
      parameter_id: parameter.id
    }
  end

  # Create a value with proper type handling based on parameter type
  def create_changeset(raw_value, parameter, timestamp, qualifiers \\ %{}) do
    param_val_map = create_map(raw_value, parameter, timestamp, qualifiers)

    schema_module = get_schema_module(parameter)

    struct(schema_module)
    |> schema_module.changeset(param_val_map)
  end

  # Get raw value (handles all storage types)
  def get_raw_value(parameter_value, parameter) do
    case get_storage_type(parameter) do
      storage
      when storage in [
             :int,
             :double,
             :bool,
             :string,
             :array_int,
             :array_double,
             :array_bool,
             :array_string
           ] ->
        # For atomic types and simple arrays, value is stored directly
        parameter_value.value

      :json ->
        # For complex types, extract from map structure
        case parameter_value.value do
          %{"value" => v} -> v
          other -> other
        end
    end
  end

  # Get display-friendly value with unit
  def get_display_value(parameter_value, parameter) do
    raw_value = get_raw_value(parameter_value, parameter)
    unit = parameter.datainfo["unit"] || ""

    case parameter.datainfo["type"] do
      "double" ->
        format_string = parameter.datainfo["fmtstr"] || "%.6g"
        formatted = ExPrintf.sprintf(format_string, [raw_value])
        append_unit(formatted, unit)

      "scaled" ->
        # Convert scaled integer to actual value
        scale = parameter.datainfo["scale"] || 1.0
        actual_value = raw_value * scale

        format_string =
          parameter.datainfo["fmtstr"] ||
            "%." <> Integer.to_string(max(0, -floor(:math.log10(scale)))) <> "f"

        formatted = ExPrintf.sprintf(format_string, [actual_value])
        append_unit(formatted, unit)

      "enum" ->
        # Find name for the numeric value
        name = find_enum_name(parameter.datainfo["members"], raw_value)
        name

      "array" ->
        "[" <>
          (raw_value |> Enum.map(&to_string/1) |> Enum.join(", ")) <>
          "]" <>
          if unit != "", do: " #{unit}", else: ""

      _ ->
        append_unit(Jason.encode!(raw_value), unit)
    end
  end

  defp append_unit(value_str, ""), do: value_str
  defp append_unit(value_str, unit), do: "#{value_str} #{unit}"

  defp find_enum_name(members, value) do
    case Enum.find(members, fn {_name, val} -> val == value end) do
      {name, _} -> name
      nil -> "unknown_#{value}"
    end
  rescue
    _ -> "error_#{value}"
  end
end
