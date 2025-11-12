defmodule SecopService.Sec_Nodes.ParameterValue.Double do
  use Ecto.Schema
  import Ecto.Changeset
  alias SecopService.Sec_Nodes.Parameter

  @derive {
    Flop.Schema,
    filterable: [:timestamp, :parameter_id],
    sortable: [:timestamp, :parameter_id],
    default_order: %{
      order_by: [:timestamp],
      order_directions: [:desc]
    }
  }

  schema "parameter_values_double" do
    field :value, :float
    field :timestamp, :utc_datetime_usec
    field :qualifiers, :map

    belongs_to :parameter, Parameter

    timestamps()
  end

  def changeset(parameter_value, attrs) do
    parameter_value
    |> cast(attrs, [:value, :timestamp, :qualifiers, :parameter_id])
    |> validate_required([:value, :timestamp, :parameter_id])
    |> foreign_key_constraint(:parameter_id)
  end
end

defmodule SecopService.Sec_Nodes.ParameterValue.ArrayDouble do
  use Ecto.Schema
  import Ecto.Changeset
  alias SecopService.Sec_Nodes.Parameter

  @derive {
    Flop.Schema,
    filterable: [:timestamp, :parameter_id],
    sortable: [:timestamp, :parameter_id],
    default_order: %{
      order_by: [:timestamp],
      order_directions: [:desc]
    }
  }

  schema "parameter_values_array_double" do
    field :value, {:array, :float}
    field :timestamp, :utc_datetime_usec
    field :qualifiers, :map

    belongs_to :parameter, Parameter

    timestamps()
  end

  def changeset(parameter_value, attrs) do
    parameter_value
    |> cast(attrs, [:value, :timestamp, :qualifiers, :parameter_id])
    |> validate_required([:value, :timestamp, :parameter_id])
    |> foreign_key_constraint(:parameter_id)
  end
end
