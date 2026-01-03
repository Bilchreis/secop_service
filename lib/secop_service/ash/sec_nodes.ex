defmodule SecopService.Ash.SecNodes do
  @moduledoc """
  Domain for managing SECoP nodes and their metadata.
  """

  use Ash.Domain,
    otp_app: :secop_service

  alias SecopService.Ash.SecNodes.SecNode
  alias SecopService.SecNodes.DescribeMessageTransformer

  resources do
    resource SecopService.Ash.SecNodes.Command
    resource SecopService.Ash.SecNodes.Module
    resource SecopService.Ash.SecNodes.ParameterValuesArrayBool
    resource SecopService.Ash.SecNodes.ParameterValuesArrayDouble
    resource SecopService.Ash.SecNodes.ParameterValuesArrayInt
    resource SecopService.Ash.SecNodes.ParameterValuesArrayString
    resource SecopService.Ash.SecNodes.ParameterValuesBool
    resource SecopService.Ash.SecNodes.ParameterValuesDouble
    resource SecopService.Ash.SecNodes.ParameterValuesInt
    resource SecopService.Ash.SecNodes.ParameterValuesJson
    resource SecopService.Ash.SecNodes.ParameterValuesString
    resource SecopService.Ash.SecNodes.Parameter
    resource SecopService.Ash.SecNodes.SecNode
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

  @doc """
  Imports a SEC_Node_Statem state, replacing any existing node with the same host:port.

  ## Parameters
  - `statem_state` - The state map from SEC_Node_Statem

  ## Returns
  - `{:ok, sec_node}` - Successfully created or updated SecNode record
  - `{:error, reason}` - Error during operation
  """
  def import_or_replace_statem_state(statem_state) do
    host = to_string(statem_state[:host])
    port = statem_state[:port]

    # Find and destroy existing node with same host:port
    SecNode
    |> Ash.Query.filter(host == ^host and port == ^port)
    |> Ash.read()
    |> case do
      {:ok, [existing | _]} ->
        Ash.destroy(existing)

      _ ->
        :ok
    end

    # Create new node
    import_statem_state(statem_state)
  end

  @doc """
  Gets a SecNode by host and port.

  ## Parameters
  - `host` - Host address as string or charlist
  - `port` - Port number as integer

  ## Returns
  - `{:ok, sec_node}` - Found SecNode
  - `{:ok, nil}` - No SecNode found
  - `{:error, reason}` - Error during query
  """
  def get_by_host_port(host, port) do
    host_str = to_string(host)

    SecNode
    |> Ash.Query.filter(host == ^host_str and port == ^port)
    |> Ash.Query.load([:modules])
    |> Ash.read_one()
  end

  @doc """
  Lists all SecNodes in the database.

  ## Options
  - `:load` - List of associations to preload (default: [:modules])

  ## Returns
  - `{:ok, [sec_node]}` - List of SecNodes
  - `{:error, reason}` - Error during query
  """
  def list_nodes(opts \\ []) do
    load = Keyword.get(opts, :load, [:modules])

    SecNode
    |> Ash.Query.load(load)
    |> Ash.read()
  end
end
