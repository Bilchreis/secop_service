defmodule SecopService.Ash.SecNodes.ParameterValuesInt do
  use Ash.Resource,
    domain: SecopService.Ash.SecNodes,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "parameter_values_int"
    repo SecopService.Repo

    references do
      reference :parameter do
        on_delete :delete
      end
    end

    custom_indexes do
      index [:parameter_id, :timestamp] do
        name "parameter_values_int_parameter_id_timestamp_index"
      end

      index [:timestamp] do
        name "parameter_values_int_timestamp_index"
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

    attribute :value, :integer do
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
    belongs_to :parameter, SecopService.Ash.SecNodes.Parameter do
      allow_nil? false
      attribute_type :integer
      public? true
    end
  end
end
