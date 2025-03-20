defmodule SecopService.Sec_Nodes.ParameterValue do
  use Ecto.Schema
  import Ecto.Changeset
  alias SecopService.Sec_Nodes.Parameter

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
    value =
      case parameter.data_info["type"] do
        # Simple types stored directly
        type when type in ["double", "int", "bool"] ->
          raw_value

        # Scaled values pre-calculate the actual value
        "scaled" ->
          raw_value * parameter.data_info["scale"]

        # Enum values store both the numeric value and its name for convenience
        "enum" ->
          # Find name for the numeric value
          name =
            parameter.data_info["members"]
            |> Enum.find(fn {_name, val} -> val == raw_value end)
            |> elem(0)

          %{numeric: raw_value, name: name}

        # Complex types
        type when type in ["array", "tuple", "struct", "matrix"] ->
          # Store with type information to assist rendering
          %{
            type: type,
            value: raw_value
          }

        # Fallback for any other type
        _ ->
          raw_value
      end

    %__MODULE__{}
    |> changeset(%{
      value: value,
      timestamp: timestamp,
      qualifiers: qualifiers,
      parameter_id: parameter.id
    })
  end

  # Helpers for working with stored values

  # Get the raw value with appropriate type handling
  def get_raw_value(parameter_value, parameter) do
    case parameter.data_info["type"] do
      type when type in ["double", "int", "bool"] ->
        parameter_value.value

      "scaled" ->
        # No need to scale again - we stored the pre-scaled value
        parameter_value.value

      "enum" ->
        # Return the numeric value
        parameter_value.value.numeric

      type when type in ["array", "tuple", "struct", "matrix"] ->
        parameter_value.value.value

      _ ->
        parameter_value.value
    end
  end

  # Get a display-friendly value with unit
  def get_display_value(parameter_value, parameter) do
    raw_value = get_raw_value(parameter_value, parameter)
    unit = parameter.data_info["unit"] || ""

    case parameter.data_info["type"] do
      "double" ->
        format_string = parameter.data_info["fmtstr"] || "%.6g"
        # Simple formatting with :io_lib.format
        formatted = :io_lib.format(String.to_charlist(format_string), [raw_value])
        "#{formatted} #{unit}"

      "scaled" ->
        format_string = parameter.data_info["fmtstr"] || "%.6g"
        formatted = :io_lib.format(String.to_charlist(format_string), [raw_value])
        "#{formatted} #{unit}"

      "enum" ->
        # Return the name for display
        parameter_value.value.name

      _ ->
        if unit == "" do
          "#{inspect(raw_value)}"
        else
          "#{inspect(raw_value)} #{unit}"
        end
    end
  end
end
