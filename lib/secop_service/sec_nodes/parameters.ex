defmodule SecopService.Sec_Nodes.Parameter do
  use Ecto.Schema
  import Ecto.Changeset

  schema "parameters" do
    field :name, :string

    # Mandatory properties:
    field :description, :string
    # Complete SECoP data info structure
    field :datainfo, :map
    field :readonly, :boolean, default: true

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

  def changeset(parameter, attrs) do
    parameter
    |> cast(attrs, [
      :name,
      :datainfo,
      :description,
      :readonly,
      :custom_properties,
      :module_id,
      :group,
      :visibility,
      :meaning,
      :checkable
    ])
    |> validate_required([:name, :description, :datainfo, :module_id])
    |> validate_datainfo()
    |> foreign_key_constraint(:module_id)
  end

  # Validate that the datainfo structure is valid according to SECoP
  defp validate_datainfo(changeset) do
    case get_change(changeset, :datainfo) do
      nil ->
        changeset

      datainfo ->
        if is_map(datainfo) && Map.has_key?(datainfo, :type) do
          changeset
        else
          add_error(changeset, :datainfo, "must contain a 'type' field")
        end
    end
  end

  # Helper to get data type
  def get_type(parameter) do
    parameter.datainfo[:type]
  end

  # Helper to get unit
  def get_unit(parameter) do
    parameter.datainfo[:unit] || ""
  end


  # Helper to get the appropriate value table/module
  def get_value_schema_module(parameter) do
    SecopService.Sec_Nodes.ParameterValue.get_schema_module(parameter)
  end

  def get_storage_type(parameter) do
    SecopService.Sec_Nodes.ParameterValue.get_storage_type(parameter)
  end
end
