defmodule SecopService.Ash.SecNodes.Token do
  use Ash.Resource,
    domain: SecopService.Ash.SecNodes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "tokens"
    repo SecopService.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    attribute :jti, :string do
      primary_key? true
      allow_nil? false
      public? true
    end

    attribute :subject, :string do
      allow_nil? false
      public? true
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :purpose, :string do
      allow_nil? false
      public? true
    end

    attribute :extra_data, :map do
      public? true
    end

    create_timestamp :created_at do
      allow_nil? false
      public? true
    end

    update_timestamp :updated_at do
      allow_nil? false
      public? true
    end
  end
end
