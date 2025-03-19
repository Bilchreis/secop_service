defmodule SecopService.Sec_Nodes.Module do
  use Ecto.Schema
  import Ecto.Changeset

  schema "modules" do
    field :name, :string
    field :description, :string
    field :interface_classes, {:array, :string}
    field :properties, :map  # JSONB column for flexible properties

    belongs_to :sec_node, SecopService.Sec_Nodes.SEC_Node
    has_many :parameters, SecopService.Sec_Nodes.Parameter
    has_many :commands,   SecopService.Sec_Nodes.Command

    timestamps()
  end

  def changeset(module, attrs) do
    module
    |> cast(attrs, [:name, :descrioption, :interface_classes, :properties, :sec_node_id])
    |> validate_required([:name, :sec_node_id])
  end
end
