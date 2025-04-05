defmodule SecopService.Sec_Nodes.SEC_Node do
  use Ecto.Schema
  import Ecto.Changeset


  @derive {
    Flop.Schema,
    filterable: [:uuid, :equipment_id, :host, :port],
    sortable:   [:uuid, :equipment_id, :host, :port, :inserted_at],
  }

  @primary_key {:uuid, Ecto.UUID, autogenerate: true}
  @derive {Phoenix.Param, key: :uuid}
  schema "sec_nodes" do
    field :equipment_id, :string
    field :host, :string
    field :port, :integer
    field :description, :string
    # JSONB full describe message
    field :describe_message, :map
    # JSONB column for flexible properties
    field :properties, :map

    has_many :modules, SecopService.Sec_Nodes.Module, foreign_key: :sec_node_id

    timestamps()
  end

  def changeset(sec_node, attrs) do
    sec_node
    |> cast(attrs, [
      :uuid,
      :equipment_id,
      :host,
      :port,
      :description,
      :describe_message,
      :properties
    ])
    |> validate_required([
      :uuid,
      :equipment_id,
      :host,
      :port,
      :description,
      :describe_message,
      :properties
    ])
  end
end
