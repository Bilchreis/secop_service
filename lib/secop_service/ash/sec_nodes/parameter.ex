defmodule SecopService.Ash.SecNodes.Parameter do
  use Ash.Resource,
    domain: SecopService.Ash.SecNodes,
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
    defaults [:read, :destroy, create: :*, update: :*]
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

    attribute :custom_properties, :map do
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
    belongs_to :module, SecopService.Ash.SecNodes.Module do
      allow_nil? false
      attribute_type :integer
      public? true
    end

    has_many :parameter_values_array_bools, SecopService.Ash.SecNodes.ParameterValuesArrayBool do
      public? true
    end

    has_many :parameter_values_array_doubles,
             SecopService.Ash.SecNodes.ParameterValuesArrayDouble do
      public? true
    end

    has_many :parameter_values_array_ints, SecopService.Ash.SecNodes.ParameterValuesArrayInt do
      public? true
    end

    has_many :parameter_values_array_strings,
             SecopService.Ash.SecNodes.ParameterValuesArrayString do
      public? true
    end

    has_many :parameter_values_bools, SecopService.Ash.SecNodes.ParameterValuesBool do
      public? true
    end

    has_many :parameter_values_doubles, SecopService.Ash.SecNodes.ParameterValuesDouble do
      public? true
    end

    has_many :parameter_values_ints, SecopService.Ash.SecNodes.ParameterValuesInt do
      public? true
    end

    has_many :parameter_values_jsons, SecopService.Ash.SecNodes.ParameterValuesJson do
      public? true
    end

    has_many :parameter_values_strings, SecopService.Ash.SecNodes.ParameterValuesString do
      public? true
    end
  end

  identities do
    identity :module_id_name, [:module_id, :name]
  end
end
