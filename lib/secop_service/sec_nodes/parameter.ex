defmodule SecopService.SecNodes.Parameter do
  use Ash.Resource,
    domain: SecopService.SecNodes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "parameters"
    repo SecopService.Repo

    references do
      reference :module do
        on_delete :delete
      end
    end

    identity_index_names module_id_name: "parameters_module_id_name_index"
  end

  actions do
    defaults [:read, :destroy]

    create :create do
    primary? true
      accept [
        :name,
        :datainfo,
        :readonly,
        :description,
        :group,
        :visibility,
        :meaning,
        :checkable,
        :custom_properties,
        :module_id
      ]

      upsert? true
      upsert_identity :module_id_name
      upsert_fields [:datainfo, :readonly, :description, :group, :visibility, :meaning, :checkable, :custom_properties]

    end

    read :by_node_uuid do
      argument :node_uuid, :uuid do
        allow_nil? false
      end

      prepare build(load: [:module])

      filter expr(module.sec_node_id == ^arg(:node_uuid))
    end

    read :get_with_context do
      argument :id, :integer do
        allow_nil? false
      end

      filter expr(id == ^arg(:id))

      prepare build(load: [module: [sec_node: [:node_id]]])
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

    attribute :datainfo, :map do
      public? true
    end

    attribute :readonly, :boolean do
      generated? true
      public? true
    end

    attribute :description, :string do
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

    attribute :custom_properties, :map do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :module, SecopService.SecNodes.Module do
      allow_nil? false
      attribute_type :integer
      public? true
    end

    has_many :parameter_values_array_bools, SecopService.SecNodes.ParameterValuesArrayBool do
      public? true
    end

    has_many :parameter_values_array_doubles,
             SecopService.SecNodes.ParameterValuesArrayDouble do
      public? true
    end

    has_many :parameter_values_array_ints, SecopService.SecNodes.ParameterValuesArrayInt do
      public? true
    end

    has_many :parameter_values_array_strings,
             SecopService.SecNodes.ParameterValuesArrayString do
      public? true
    end

    has_many :parameter_values_bools, SecopService.SecNodes.ParameterValuesBool do
      public? true
    end

    has_many :parameter_values_doubles, SecopService.SecNodes.ParameterValuesDouble do
      public? true
    end

    has_many :parameter_values_ints, SecopService.SecNodes.ParameterValuesInt do
      public? true
    end

    has_many :parameter_values_jsons, SecopService.SecNodes.ParameterValuesJson do
      public? true
    end

    has_many :parameter_values_strings, SecopService.SecNodes.ParameterValuesString do
      public? true
    end
  end

  identities do
    identity :module_id_name, [:module_id, :name]
  end
end
