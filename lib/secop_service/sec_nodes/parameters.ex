defmodule SecopService.Sec_Nodes.Parameter do
  use Ecto.Schema
  import Ecto.Changeset

  schema "parameters" do
    field :name, :string
    field :data_info, :map  # Complete SECoP data info structure
    field :readonly, :boolean, default: false

    belongs_to :module, SecopService.Sec_Nodes.Module
    has_many :parameter_values, SecopService.Sec_Nodes.ParameterValue

    timestamps()
  end

  def changeset(parameter, attrs) do
    parameter
    |> cast(attrs, [:name, :data_info, :readonly, :module_id])
    |> validate_required([:name, :data_info, :module_id])
    |> validate_data_info()
    |> foreign_key_constraint(:module_id)
  end

  # Validate that the data_info structure is valid according to SECoP
  defp validate_data_info(changeset) do
    case get_change(changeset, :data_info) do
      nil -> changeset
      data_info ->
        if is_map(data_info) && Map.has_key?(data_info, "type") do
          changeset
        else
          add_error(changeset, :data_info, "must contain a 'type' field")
        end
    end
  end

  # Helper to get data type
  def get_type(parameter) do
    parameter.data_info["type"]
  end

  # Helper to get unit
  def get_unit(parameter) do
    parameter.data_info["unit"] || ""
  end
end
