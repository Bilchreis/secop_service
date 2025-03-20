defmodule SecopService.Sec_Nodes.Command do
  use Ecto.Schema
  import Ecto.Changeset

  schema "commands" do
    field :name, :string
    field :description, :string
    # Complete SECoP data info structure
    field :data_info, :map
    # JSONB column for flexible properties
    field :properties, :map
    # JSONB column for argument data type
    field :argument, :map
    # JSONB column for result data type
    field :result, :map

    belongs_to :module, SecopService.Sec_Nodes.Module

    timestamps()
  end

  def changeset(command, attrs) do
    command
    |> cast(attrs, [:name, :description, :data_info, :properties, :module_id, :argument, :result])
    |> validate_required([:name, :data_info, :module_id])
    |> validate_command_data_info()
    |> foreign_key_constraint(:module_id)
  end

  # Validate that the data_info structure is valid according to SECoP command requirements
  defp validate_command_data_info(changeset) do
    case get_change(changeset, :data_info) do
      nil ->
        changeset

      data_info ->
        cond do
          not is_map(data_info) ->
            add_error(changeset, :data_info, "must be a map")

          Map.get(data_info, "type") != "command" ->
            add_error(changeset, :data_info, "must have type 'command'")

          true ->
            # Validate argument and result if present
            validate_command_components(changeset, data_info)
        end
    end
  end

  # Validate argument and result structures if present
  defp validate_command_components(changeset, data_info) do
    changeset
    |> validate_command_argument(data_info)
    |> validate_command_result(data_info)
  end

  defp validate_command_argument(changeset, data_info) do
    case Map.get(data_info, "argument") do
      # Argument is optional
      nil ->
        changeset

      argument when is_map(argument) ->
        # Argument must have a type field if present
        if Map.has_key?(argument, "type") do
          changeset
        else
          add_error(changeset, :data_info, "argument must contain a 'type' field")
        end

      _ ->
        add_error(changeset, :data_info, "argument must be a map or null")
    end
  end

  defp validate_command_result(changeset, data_info) do
    case Map.get(data_info, "result") do
      # Result is optional
      nil ->
        changeset

      result when is_map(result) ->
        # Result must have a type field if present
        if Map.has_key?(result, "type") do
          changeset
        else
          add_error(changeset, :data_info, "result must contain a 'type' field")
        end

      _ ->
        add_error(changeset, :data_info, "result must be a map or null")
    end
  end

  # Helper functions for working with commands

  @doc """
  Returns true if the command has an argument.
  """
  def has_argument?(command) do
    command.data_info["argument"] != nil
  end

  @doc """
  Returns the argument data type map if present, nil otherwise.
  """
  def get_argument_type(command) do
    command.data_info["argument"]
  end

  @doc """
  Returns true if the command returns a result.
  """
  def has_result?(command) do
    command.data_info["result"] != nil
  end

  @doc """
  Returns the result data type map if present, nil otherwise.
  """
  def get_result_type(command) do
    command.data_info["result"]
  end

  @doc """
  Returns a friendly description of the command signature.
  Example: "invert(bool) → int"
  """
  def get_signature(command) do
    arg_type =
      if has_argument?(command) do
        case get_argument_type(command)["type"] do
          "struct" -> "object"
          "array" -> "array"
          "tuple" -> "tuple"
          type -> type
        end
      else
        "void"
      end

    result_type =
      if has_result?(command) do
        case get_result_type(command)["type"] do
          "struct" -> "object"
          "array" -> "array"
          "tuple" -> "tuple"
          type -> type
        end
      else
        "void"
      end

    "#{command.name}(#{arg_type}) → #{result_type}"
  end
end
