defmodule SecopService.Sec_Nodes.SEC_Node do
  use Ecto.Schema
  import Ecto.Changeset
  alias SecopService.Util

  @derive {
    Flop.Schema,
    filterable: [:uuid, :equipment_id, :host, :port],
    sortable: [:uuid, :equipment_id, :host, :port, :inserted_at],
    default_order: %{
      order_by: [:inserted_at, :equipment_id],
      order_directions: [:desc, :asc]
    }
  }

  @primary_key {:uuid, Ecto.UUID, autogenerate: true}
  @derive {Phoenix.Param, key: :uuid}
  schema "sec_nodes" do
    field :equipment_id, :string
    field :host, :string
    field :port, :integer
    field :description, :string
    field :firmware, :string
    field :implementor, :string
    field :timeout, :integer

    # JSONB full describe message
    field :describe_message, :map
    field :describe_message_raw, :string
    # JSONB column for flexible properties
    field :custom_properties, :map

    field :check_result, :map

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
      :describe_message_raw,
      :custom_properties,
      :firmware,
      :implementor,
      :timeout,
      :check_result
    ])
    |> validate_required([
      :uuid,
      :equipment_id,
      :host,
      :port,
      :description,
      :describe_message,
      :describe_message_raw,
      :custom_properties,
      :check_result
    ])
  end

  def display_description(sec_node) do
    sec_node.description
    |> String.split("\n")
    |> Enum.map(&Phoenix.HTML.html_escape/1)
    |> Enum.intersperse(Phoenix.HTML.raw("<br>"))
  end

  def display_equipment_id(sec_node) do
    Util.display_name(sec_node.equipment_id)
  end

  def get_node_id(sec_node) do
    {String.to_charlist(sec_node.host), sec_node.port}
  end

  def get_id_str(sec_node) do
    "#{sec_node.host}:#{sec_node.port}"
  end

  def get_values_pubsub_topic(sec_node) do
    "value_update:#{sec_node.host}:#{sec_node.port}"
  end

  def get_error_pubsub_topic(sec_node) do
    "error_update:#{sec_node.host}:#{sec_node.port}"
  end
end
