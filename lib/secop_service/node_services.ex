defmodule SecopService.NodeSupervisor do
  # Automatically defines child_spec/1
  require Logger
  use DynamicSupervisor
  alias SecopService.NodeValues

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(node_db) do
    opts = %{
      node_db: node_db
    }

    result = DynamicSupervisor.start_child(__MODULE__, {SecopService.NodeServices, opts})

    IO.inspect(result)

    result
  end

  def stop_node_services(node_id) do
    case get_services_pid(node_id) do
      nil ->
        Logger.info("No Services running found for ID: #{node_id}")
        {:error, :not_found}

      pid ->
        Logger.info("Stopping Services for ID: #{node_id}")
        DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  # node_id
  def services_running?({host, port}) do
    get_services_pid({host, port}) != nil
  end

  # uuid
  def services_running?(uuid) do
    list_node_id_services()
    |> Enum.any?(fn node_id ->
      {:ok, node_db} = NodeValues.get_node_db(node_id)
      node_db.uuid == uuid
    end)
  end

  def get_services_pid(node_id) do
    case Registry.lookup(Registry.NodeServices, node_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  def list_node_id_services() do
    Registry.select(Registry.NodeServices, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end
end

defmodule SecopService.NodeServices do
  use Supervisor
  require Logger
  alias SecopService.Sec_Nodes.SEC_Node

  @moduledoc """
  Supervisor for all processes related to a specific SEC Node, including:
  - NodeValues: Buffering and caching of incoming node values
  - DBWriter: Process responsible for writing node values to the database
  - PlotCacheSupervisor: Dynamic supervisor for plot cache processes for this node
    - this entails a process for each parameter of the SEC node
    - sends updates to the liveview plot components only every x seconds to reduce the number of updates

  """

  def start_link(node_db) do
    node_id = SEC_Node.get_node_id(node_db)

    Supervisor.start_link(__MODULE__, node_db,
      name: {:via, Registry, {Registry.NodeServices, node_id}}
    )
  end

  def stop(node_id) do
    case Registry.lookup(Registry.NodeServices, node_id) do
      [{supervisor_pid, _}] ->
        Logger.info("Stopping NodeServices for #{inspect(node_id)}")
        Supervisor.stop(supervisor_pid, :normal)

      [] ->
        Logger.warning(
          "Attempted to stop NodeServices for #{inspect(node_id)}, but no such service was found."
        )

        {:error, :not_found}
    end
  end

  @impl true
  def init(node_db) do
    Logger.info("Initializing NodeServices for #{inspect(SEC_Node.get_node_id(node_db))}")

    children = [
      # Buffer process for this specific node
      {SecopService.NodeValues, node_db},

      # Dynamic supervisor for parameter plot caches
      {SecopService.PlotCacheSupervisor, node_db},

      # Dispatcher process for plot cache updates
      {SecopService.PlotCacheDispatcher, SEC_Node.get_node_id(node_db)},

      # DB Writer process for this specific node
      {SecopService.NodeDBWriter, node_db}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  def child_spec(opts) do
    %{
      id: opts.node_db.uuid,
      start: {__MODULE__, :start_link, [opts.node_db]},
      type: :supervisor,
      restart: :transient,
      shutdown: :infinity
    }
  end
end
