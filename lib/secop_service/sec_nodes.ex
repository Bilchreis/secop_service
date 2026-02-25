defmodule SecopService.SecNodes do
  @moduledoc """
  Domain for managing SECoP nodes and their metadata.
  """

  use Ash.Domain,
    otp_app: :secop_service

  alias SecopService.SecNodes.SecNode
  alias SecopService.DescribeMessageTransformer

  resources do
    resource SecopService.SecNodes.Command
    resource SecopService.SecNodes.Module
    resource SecopService.SecNodes.ParameterValueArrayBool
    resource SecopService.SecNodes.ParameterValueArrayDouble
    resource SecopService.SecNodes.ParameterValueArrayInt
    resource SecopService.SecNodes.ParameterValueArrayString
    resource SecopService.SecNodes.ParameterValueBool
    resource SecopService.SecNodes.ParameterValueDouble
    resource SecopService.SecNodes.ParameterValueInt
    resource SecopService.SecNodes.ParameterValueJson
    resource SecopService.SecNodes.ParameterValueString
    resource SecopService.SecNodes.Parameter
    resource SecopService.SecNodes.SecNode
  end

  @doc """
  Imports a SEC_Node_Statem state into the database.

  This is the primary high-level function for persisting SECoP node descriptive data.

  ## Parameters
  - `statem_state` - The state map from SEC_Node_Statem containing description and metadata

  ## Returns
  - `{:ok, sec_node}` - Successfully created SecNode record
  - `{:error, changeset}` - Validation or persistence error

  ## Examples

      iex> {:ok, state} = SEC_Node_Statem.get_state(pid)
      iex> SecopService.Ash.SecNodes.import_statem_state(state)
      {:ok, %SecNode{equipment_id: "sim_gas_dosing", ...}}
  """
  def import_statem_state(statem_state) do
    statem_state
    |> DescribeMessageTransformer.transform()
    |> then(fn prepared_data ->
      SecNode
      |> Ash.Changeset.for_create(:create, prepared_data)
      |> Ash.create()
    end)
  end
end
