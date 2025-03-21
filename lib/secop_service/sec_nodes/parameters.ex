defmodule SecopService.Sec_Nodes.Parameter do
  use Ecto.Schema
  import Ecto.Changeset

  schema "parameters" do
    field :name, :string
    field :description, :string
    # Complete SECoP data info structure
    field :datainfo, :map
    field :readonly, :boolean, default: true
    # JSONB column for flexible properties
    field :properties, :map

    belongs_to :module, SecopService.Sec_Nodes.Module
    has_many :parameter_values, SecopService.Sec_Nodes.ParameterValue

    timestamps()
  end

  def changeset(parameter, attrs) do
    parameter
    |> cast(attrs, [:name, :datainfo, :description, :readonly, :properties, :module_id])
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
end
