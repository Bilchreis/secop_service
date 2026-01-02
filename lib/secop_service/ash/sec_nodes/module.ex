defmodule SecopService.Ash.SecNodes.Module do
  use Ash.Resource,
    domain: SecopService.Ash.SecNodes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "modules"
    repo SecopService.Repo

    references do
      reference :sec_node do
        on_delete :delete
      end
    end

    identity_index_names sec_node_id_name: "modules_sec_node_id_name_index"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :description,
        :interface_classes,
        :highest_interface_class,
        :visibility,
        :group,
        :meaning,
        :implementor,
        :custom_properties,
        :sec_node_id
      ]

      argument :parameters, {:array, :map}
      argument :commands, {:array, :map}

      change manage_relationship(:parameters, type: :create)
      change manage_relationship(:commands, type: :create)
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

    attribute :interface_classes, {:array, :string} do
      public? true
    end

    attribute :highest_interface_class, :string do
      public? true
    end

    attribute :visibility, :string do
      public? true
    end

    attribute :group, :string do
      public? true
    end

    attribute :meaning, :map do
      public? true
    end

    attribute :implementor, :string do
      public? true
    end

    attribute :custom_properties, :map do
      public? true
    end


    timestamps()

  end

  relationships do
    belongs_to :sec_node, SecopService.Ash.SecNodes.SecNode do
      destination_attribute :uuid
      allow_nil? false
      public? true
    end

    has_many :commands, SecopService.Ash.SecNodes.Command do
      public? true
    end

    has_many :parameters, SecopService.Ash.SecNodes.Parameter do
      public? true
    end
  end

  identities do
    identity :sec_node_id_name, [:sec_node_id, :name]
  end
end
