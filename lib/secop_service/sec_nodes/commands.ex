defmodule SecopService.Sec_Nodes.Command do
  use Ecto.Schema
  import Ecto.Changeset

  schema "commands" do
    field :name, :string
    field :description, :string
    # Complete SECoP data info structure
    field :datainfo, :map

    # JSONB column for argument data type
    field :argument, :map
    # JSONB column for result data type
    field :result, :map

    # Optional properties:
    field :group, :string
    field :visibility, :string
    field :meaning, :map
    field :checkable, :boolean

    # JSONB column for custom properties
    field :custom_properties, :map

    belongs_to :module, SecopService.Sec_Nodes.Module

    timestamps()
  end

  def changeset(command, attrs) do
    command
    |> cast(attrs, [
      :name,
      :description,
      :datainfo,
      :custom_properties,
      :module_id,
      :argument,
      :result,
      :group,
      :visibility,
      :meaning,
      :checkable
    ])
    |> validate_required([:name, :datainfo, :module_id])
    |> validate_command_datainfo()
    |> foreign_key_constraint(:module_id)
  end

  # Validate that the datainfo structure is valid according to SECoP command requirements
  defp validate_command_datainfo(changeset) do
    case get_change(changeset, :datainfo) do
      nil ->
        changeset

      datainfo ->
        cond do
          not is_map(datainfo) ->
            add_error(changeset, :datainfo, "must be a map")

          Map.get(datainfo, :type) != "command" ->
            add_error(changeset, :datainfo, "must have type 'command'")

          true ->
            # Validate argument and result if present
            validate_command_components(changeset, datainfo)
        end
    end
  end

  # Validate argument and result structures if present
  defp validate_command_components(changeset, datainfo) do
    changeset
    |> validate_command_argument(datainfo)
    |> validate_command_result(datainfo)
  end

  defp validate_command_argument(changeset, datainfo) do
    case Map.get(datainfo, "argument") do
      # Argument is optional
      nil ->
        changeset

      argument when is_map(argument) ->
        # Argument must have a type field if present
        if Map.has_key?(argument, "type") do
          changeset
        else
          add_error(changeset, :datainfo, "argument must contain a 'type' field")
        end

      _ ->
        add_error(changeset, :datainfo, "argument must be a map or null")
    end
  end

  defp validate_command_result(changeset, datainfo) do
    case Map.get(datainfo, "result") do
      # Result is optional
      nil ->
        changeset

      result when is_map(result) ->
        # Result must have a type field if present
        if Map.has_key?(result, "type") do
          changeset
        else
          add_error(changeset, :datainfo, "result must contain a 'type' field")
        end

      _ ->
        add_error(changeset, :datainfo, "result must be a map or null")
    end
  end

  # Helper functions for working with commands

  @doc """
  Returns true if the command has an argument.
  """
  def has_argument?(command) do
    command.datainfo["argument"] != nil
  end

  @doc """
  Returns the argument data type map if present, nil otherwise.
  """
  def get_argument_type(command) do
    command.datainfo["argument"]
  end

  @doc """
  Returns true if the command returns a result.
  """
  def has_result?(command) do
    command.datainfo["result"] != nil
  end

  @doc """
  Returns the result data type map if present, nil otherwise.
  """
  def get_result_type(command) do
    command.datainfo["result"]
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
