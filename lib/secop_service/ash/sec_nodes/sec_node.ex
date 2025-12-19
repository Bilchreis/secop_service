defmodule SecopService.Ash.SecNodes.SecNode do
  use Ash.Resource,
    domain: SecopService.Ash.SecNodes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "sec_nodes"
    repo SecopService.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
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

    attribute :inserted_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    update_timestamp :updated_at do
      allow_nil? false
      public? true
    end
  end

  relationships do
    has_many :modules, SecopService.Ash.SecNodes.Module do
      source_attribute :uuid
      public? true
    end
  end
end
