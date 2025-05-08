defmodule SecopService.Sec_Nodes.ParameterValue do
  use Ecto.Schema
  import Ecto.Changeset
  alias SecopService.Sec_Nodes.Parameter
  alias ExPrintf
  require Logger

  @derive {
    Flop.Schema,
    filterable: [:timestamp, :parameter_id],
    sortable: [:timestamp, :parameter_id],
    default_order: %{
      order_by: [:timestamp],
      order_directions: [:desc]
    }
  }

  schema "parameter_values" do
    # Stores simple values directly, complex values as structures
    field :value, :map
    field :timestamp, :utc_datetime_usec
    # For storing metadata like status codes
    field :qualifiers, :map

    belongs_to :parameter, Parameter

    timestamps()
  end

  def changeset(parameter_value, attrs) do
    parameter_value
    |> cast(attrs, [:value, :timestamp, :qualifiers, :parameter_id])
    |> validate_required([:value, :timestamp, :parameter_id])
    |> foreign_key_constraint(:parameter_id)
  end

  # Create a value with proper type handling based on parameter type
  def create_with_parameter(raw_value, parameter, timestamp, qualifiers \\ %{}) do
    # Convert Unix timestamp to DateTime if needed
    formatted_timestamp =
      case timestamp do
        nil ->
          DateTime.utc_now()

        %DateTime{} = dt ->
          dt

        unix_time when is_float(unix_time) ->
          # Convert Unix timestamp to DateTime
          secs = trunc(unix_time)
          usecs = trunc((unix_time - secs) * 1_000_000)
          {:ok, dt} = DateTime.from_unix(secs)
          %{dt | microsecond: {usecs, 6}}

        _other ->
          Logger.warning("Invalid timestamp format: #{inspect(timestamp)}, using current time")
          DateTime.utc_now()
      end

    # Ensure the value is properly formatted as a map for JSONB storage
    formatted_value =
      case parameter.datainfo["type"] do
        # Simple types must be wrapped in a map for JSONB storage
        "double" ->
          %{type: "double", value: raw_value}

        "int" ->
          %{type: "int", value: raw_value}

        "bool" ->
          %{type: "bool", value: raw_value}

        # Scaled values pre-calculate the actual value
        "scaled" ->
          scale = parameter.datainfo["scale"] || 1.0
          %{type: "scaled", value: raw_value * scale}

        # Enum values store both the numeric value and its name for convenience
        "enum" ->
          # Find name for the numeric value (with error handling)
          name =
            try do
              parameter.datainfo["members"]
              |> Enum.find(fn
                {_name, val} -> val == raw_value
                _ -> false
              end)
              |> case do
                {name, _} -> name
                nil -> "unknown_#{raw_value}"
                _ -> "unknown"
              end
            rescue
              e ->
                Logger.error("Error finding enum name: #{inspect(e)}")
                "error_#{raw_value}"
            end

          %{type: "enum", numeric: raw_value, name: name}

        # Complex types
        type when type in ["array", "tuple", "struct", "matrix"] ->
          # Store with type information to assist rendering
          %{
            type: type,
            value: raw_value
          }

        # Fallback for any other type - ALWAYS wrap in a map
        type ->
          %{type: type || "unknown", value: raw_value}
      end

    %__MODULE__{}
    |> changeset(%{
      value: formatted_value,
      timestamp: formatted_timestamp,
      qualifiers: qualifiers,
      parameter_id: parameter.id
    })
  end

  # Helpers for working with stored values

  # Get the raw value with appropriate type handling
  def get_raw_value(parameter_value, parameter) do
    case parameter_value.value do
      # Handle different map structures
      %{"value" => v} ->
        v

      %{"numeric" => n} ->
        n

      nil ->
        nil

      # Fallback for direct values (should not happen with new code)
      value when not is_map(value) ->
        Logger.warning("Unexpected direct value in parameter_value: #{inspect(value)}")
        value

      # Handle unknown map structures
      other ->
        Logger.debug("Unknown value structure: #{inspect(other)}")
        other
    end
  end

  # Get a display-friendly value with unit
  def get_display_value(parameter_value, parameter) do
    raw_value = get_raw_value(parameter_value, parameter)

    unit = parameter.datainfo["unit"] || ""

    case parameter.datainfo["type"] do
      "double" ->
        format_string = parameter.datainfo["fmtstr"] || "%.6g"
        # Simple formatting with :io_lib.format
        formatted = ExPrintf.sprintf(format_string, [raw_value])
        "#{formatted} #{unit}"

      "scaled" ->
        format_string = parameter.datainfo["fmtstr"] || "%.6g"
        formatted = ExPrintf.sprintf(format_string, [raw_value])
        "#{formatted} #{unit}"

      "enum" ->
        # Return the name for display
        case parameter_value.value do
          %{name: name} -> name
          _ -> "#{raw_value}"
        end



      _ ->
        if unit == "" do
          "#{Jason.encode!(raw_value)}"
        else
          "#{Jason.encode!(raw_value)} #{unit}"
        end
    end
  end
end
