defmodule SecopService.Ash.SecNodes.User do
  use Ash.Resource,
    domain: SecopService.Ash.SecNodes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "users"
    repo SecopService.Repo

    identity_index_names email: "users_unique_email_index"
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id do
      public? true
    end

    attribute :email, :ci_string do
      allow_nil? false
      sensitive? true
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
      public? true
    end

    attribute :confirmed_at, :utc_datetime_usec do
      public? true
    end
  end

  relationships do
    has_many :api_keys, SecopService.Ash.SecNodes.ApiKey do
      public? true
    end
  end

  identities do
    identity :email, [:email]
  end
end
