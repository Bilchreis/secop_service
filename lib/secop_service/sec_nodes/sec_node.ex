defmodule SecopService.Sec_Nodes.SEC_Node do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sec_nodes" do
    field :equipment_id, :string
    field :host, :string
    field :port, :integer
    field :description, :string
    field :describe_message, :map    # JSONB full describe message
    field :properties, :map  # JSONB column for flexible properties
    field :uuid, Ecto.UUID, primary_key: true

    has_many :modules, SecopService.Sec_Nodes.Module

    timestamps()
  end

  def changeset(sec_node, attrs) do
    sec_node
    |> cast(attrs, [:uuid, :equipment_id, :host, :port, :description, :decribe_message, :properties])
    |> validate_required([:uuid, :equipment_id, :host, :port, :description, :describe_message, :properties])
  end
end
