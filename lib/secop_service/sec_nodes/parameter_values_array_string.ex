defmodule SecopService.SecNodes.ParameterValuesArrayString do
  use Ash.Resource,
    domain: SecopService.SecNodes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "parameter_values_array_string"
    repo SecopService.Repo

    references do
      reference :parameter do
        on_delete :delete
      end
    end

    custom_indexes do
      index [:parameter_id, :timestamp] do
        name "parameter_values_array_string_parameter_id_timestamp_index"
      end

      index [:timestamp] do
        name "parameter_values_array_string_timestamp_index"
      end
    end
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

    attribute :value, {:array, :string} do
      allow_nil? false
      public? true
    end

    attribute :timestamp, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :qualifiers, :map do
      public? true
    end


    timestamps()
  end

  relationships do
    belongs_to :parameter, SecopService.SecNodes.Parameter do
      allow_nil? false
      attribute_type :integer
      public? true
    end
  end
end
