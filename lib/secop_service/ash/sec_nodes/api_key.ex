defmodule SecopService.Ash.SecNodes.ApiKey do
  use Ash.Resource,
    domain: SecopService.Ash.SecNodes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "api_keys"
    repo SecopService.Repo

    identity_index_names api_key: "api_keys_unique_api_key_index"
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id do
      public? true
    end

    attribute :api_key_hash, :binary do
      allow_nil? false
      sensitive? true
      public? true
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :user, SecopService.Ash.SecNodes.User do
      public? true
    end
  end

  identities do
    identity :api_key, [:api_key_hash]
  end
end
