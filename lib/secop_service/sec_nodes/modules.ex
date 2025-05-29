defmodule SecopService.Sec_Nodes.Module do
  use Ecto.Schema
  import Ecto.Changeset
  alias SecopService.Util

  schema "modules" do
    field :name, :string

    # mandatory properties
    field :description, :string
    field :interface_classes, {:array, :string}
    field :highest_interface_class, :string

    # optional properties
    field :visibility, :string
    field :group, :string
    field :meaning, :map
    field :implementor, :string

    # JSONB column for flexible properties
    field :custom_properties, :map

    belongs_to :sec_node, SecopService.Sec_Nodes.SEC_Node,
      foreign_key: :sec_node_id,
      references: :uuid,
      type: Ecto.UUID

    has_many :parameters, SecopService.Sec_Nodes.Parameter
    has_many :commands, SecopService.Sec_Nodes.Command

    timestamps()
  end

  def changeset(module, attrs) do
    module
    |> cast(attrs, [
      :name,
      :description,
      :interface_classes,
      :highest_interface_class,
      :custom_properties,
      :sec_node_id,
      :visibility,
      :group,
      :meaning,
      :implementor
    ])
    |> validate_required([:name, :sec_node_id, :description, :interface_classes])
  end

  def display_name(module) do
    Util.display_name(module.name)
  end
end
