defmodule SecantService.SecNodes.Command do
  use Ash.Resource,
    domain: SecantService.SecNodes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "commands"
    repo SecantService.Repo

    references do
      reference :module do
        on_delete :delete
      end
    end

    identity_index_names module_id_name: "commands_module_id_name_index"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :name,
        :description,
        :datainfo,
        :custom_properties,
        :argument,
        :result,
        :group,
        :visibility,
        :meaning,
        :checkable,
        :module_id
      ]

      upsert? true
      upsert_identity :module_id_name

      upsert_fields [
        :description,
        :datainfo,
        :custom_properties,
        :argument,
        :result,
        :group,
        :visibility,
        :meaning,
        :checkable
      ]
    end
  end

  attributes do
    attribute :id, :integer do
      primary_key? true
      allow_nil? false
      generated? true
      public? true
    end

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :datainfo, :map do
      public? true
    end

    attribute :custom_properties, :map do
      public? true
    end

    attribute :argument, :map do
      public? true
    end

    attribute :result, :map do
      public? true
    end

    attribute :group, :string do
      public? true
    end

    attribute :visibility, :string do
      public? true
    end

    attribute :meaning, :map do
      public? true
    end

    attribute :checkable, :boolean do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :module, SecantService.SecNodes.Module do
      allow_nil? false
      attribute_type :integer
      public? true
    end
  end

  identities do
    identity :module_id_name, [:module_id, :name]
  end
end
