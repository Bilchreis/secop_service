defmodule SecopService.SecNodes.SecNode do
  use Ash.Resource,
    domain: SecopService.SecNodes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "sec_nodes"
    repo SecopService.Repo

    custom_indexes do
      index [:equipment_id] do
        name "equipment_id_index"
      end

    end
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      prepare build(load: [:values_pubsub_topic, :processed_values_pubsub_topic, :error_pubsub_topic])
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

    timestamps()
  end

  calculations do
    calculate :values_pubsub_topic, :string, expr("value_update:" <> ^ref(:host) <> ":" <> fragment("CAST(? AS TEXT)", ^ref(:port)))
    calculate :processed_values_pubsub_topic, :string, expr("value_update:processed:" <> ^ref(:host) <> ":" <> fragment("CAST(? AS TEXT)", ^ref(:port)))
    calculate :error_pubsub_topic, :string, expr("error_update:" <> ^ref(:host) <> ":" <> fragment("CAST(? AS TEXT)", ^ref(:port)))
  end

  relationships do
    has_many :modules, SecopService.SecNodes.Module do
      source_attribute :uuid
      public? true
    end
  end
end
