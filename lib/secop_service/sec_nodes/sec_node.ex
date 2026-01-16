defmodule SecopService.SecNodes.SecNode do
  use Ash.Resource,
    domain: SecopService.SecNodes,
    data_layer: AshPostgres.DataLayer,
    primary_read_warning?: false

  alias SecopService.Util

  @ash_pagify_options %{
    default_limit: 10
    # scopes
  }
  def ash_pagify_options, do: @ash_pagify_options

  postgres do
    table "sec_nodes"
    repo SecopService.Repo

    custom_indexes do
      index [:equipment_id] do
        name "equipment_id_index"
      end
    end
  end

  code_interface do
    define :node_only, action: :node_only
  end

  actions do
    defaults [:destroy]

    read :node_only do
      prepare build(
                sort: [{:inserted_at, :desc}],
                load: [
                  :node_id,
                  :values_pubsub_topic,
                  :processed_values_pubsub_topic,
                  :error_pubsub_topic,
                  :node_id_str,
                  :display_description,
                  :display_equipment_id
                ]
              )

      pagination offset?: true,
                 default_limit: @ash_pagify_options.default_limit,
                 countable: true,
                 required?: false
    end

    read :read do
      primary? true

      prepare build(
                load: [
                  :node_id,
                  :values_pubsub_topic,
                  :processed_values_pubsub_topic,
                  :error_pubsub_topic,
                  :node_id_str,
                  :display_description,
                  :display_equipment_id,
                  modules: [:parameters, :commands]
                ]
              )
    end

    # Check if single UUID exists
    read :exists_by_uuid do
      argument :uuid, :uuid do
        allow_nil? false
      end

      filter expr(uuid == ^arg(:uuid))

      prepare build(select: [:uuid], load: [])

      get? true
    end

    # Check which UUIDs exist (for batch checking)
    read :exists_by_uuids do
      argument :uuids, {:array, :uuid} do
        allow_nil? false
      end

      filter expr(uuid in ^arg(:uuids))

      prepare build(select: [:uuid], load: [])
    end

    create :create do
      accept [
        :uuid,
        :equipment_id,
        :host,
        :port,
        :description,
        :firmware,
        :implementor,
        :timeout,
        :describe_message,
        :describe_message_raw,
        :custom_properties,
        :check_result
      ]

      argument :modules, {:array, :map}

      change manage_relationship(:modules, type: :create)
    end

    create :upsert do
      accept [
        :uuid,
        :equipment_id,
        :host,
        :port,
        :description,
        :firmware,
        :implementor,
        :timeout,
        :describe_message,
        :describe_message_raw,
        :custom_properties,
        :check_result
      ]

      argument :modules, {:array, :map}

      upsert? true
      upsert_identity :unique_uuid

      upsert_fields [
        :equipment_id,
        :host,
        :port,
        :description,
        :firmware,
        :implementor,
        :timeout,
        :describe_message,
        :describe_message_raw,
        :custom_properties,
        :check_result
      ]

      change manage_relationship(:modules, type: :create)
    end
  end

  attributes do
    attribute :uuid, :uuid do
      primary_key? true
      allow_nil? false
      public? true
    end

    attribute :equipment_id, :string do
      allow_nil? false
      public? true
    end

    attribute :host, :string do
      allow_nil? false
      public? true
    end

    attribute :port, :integer do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :firmware, :string do
      public? true
    end

    attribute :implementor, :string do
      public? true
    end

    attribute :timeout, :integer do
      public? true
    end

    attribute :describe_message, :map do
      public? true
    end

    attribute :describe_message_raw, :string do
      public? true
    end

    attribute :custom_properties, :map do
      public? true
    end

    attribute :check_result, :map do
      public? true
    end

    timestamps(public?: true)
  end

  relationships do
    has_many :modules, SecopService.SecNodes.Module do
      source_attribute :uuid
      public? true
    end
  end

  calculations do
    calculate :values_pubsub_topic,
              :string,
              expr(
                "value_update:" <> ^ref(:host) <> ":" <> fragment("CAST(? AS TEXT)", ^ref(:port))
              )

    calculate :processed_values_pubsub_topic,
              :string,
              expr(
                "value_update:processed:" <>
                  ^ref(:host) <> ":" <> fragment("CAST(? AS TEXT)", ^ref(:port))
              )

    calculate :error_pubsub_topic,
              :string,
              expr(
                "error_update:" <> ^ref(:host) <> ":" <> fragment("CAST(? AS TEXT)", ^ref(:port))
              )

    calculate :node_id_str,
              :string,
              expr(^ref(:host) <> ":" <> fragment("CAST(? AS TEXT)", ^ref(:port)))

    calculate :node_id, :term, fn records, _context ->
      Enum.map(records, fn record ->
        {String.to_charlist(record.host), record.port}
      end)
    end

    calculate :display_description, :string, fn records, _context ->
      Enum.map(records, fn record ->
        record.description
        |> String.split("\n")
        |> Enum.map(&Phoenix.HTML.html_escape/1)
        |> Enum.intersperse(Phoenix.HTML.raw("<br>"))
      end)
    end

    calculate :display_equipment_id, :string, fn records, _context ->
      Enum.map(records, fn record ->
        Util.display_name(record.equipment_id)
      end)
    end
  end

  identities do
    identity :unique_uuid, [:uuid]
  end
end
