defmodule SecopService.NodeDBWriter do
  use GenServer
  require Logger

  alias SecopService.Repo

  @pubsub_name :secop_client_pubsub
  # Batch parameter values for 5 seconds
  @batch_interval 10_000
  # Safety limit for batch size
  @max_batch_size 1000

  # Client API

  def start_link(opts) do
    GenServer.start_link(
      __MODULE__,
      opts,
      name: via_tuple(opts)
    )
  end

  def update_parameter(node_uuid, module, parameter, data_report) do
    GenServer.cast(via_tuple(node_uuid), {:parameter_update, module, parameter, data_report})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # Subscribe to node's topic for parameter updates
    topic = "value_update:#{opts[:host]}:#{opts[:port]}"
    Phoenix.PubSub.subscribe(@pubsub_name, topic)

    Logger.info("Started DB writer for Node: #{opts[:equipment_id]} (#{opts[:uuid]})")

    # Build parameter cache with full parameter records once at startup
    parameter_cache = build_parameter_cache(opts[:uuid])

    # Log cache stats
    cache_size = map_size(parameter_cache)

    Logger.info(
      "Built parameter cache for node #{opts[:equipment_id]} with #{cache_size} parameters"
    )

    # Start batch flush timer
    schedule_batch_flush()

    {:ok,
     %{
       host: opts[:host],
       port: opts[:port],
       equipment_id: opts[:equipment_id],
       uuid: opts[:uuid],
       parameter_batch: [],
       batch_start_time: DateTime.utc_now(),
       # Cache of full parameter records (built once, never updated)
       parameter_cache: parameter_cache
     }}
  end

  @impl true
  def handle_cast({:parameter_update, module, parameter, value, timestamp, qualifiers}, state) do
    # Add to batch
    updated_batch = [{module, parameter, value, timestamp, qualifiers} | state.parameter_batch]

    # Check if we need to flush based on size
    if length(updated_batch) >= @max_batch_size do
      new_state = flush_parameter_batch(%{state | parameter_batch: updated_batch})
      {:noreply, new_state}
    else
      {:noreply, %{state | parameter_batch: updated_batch}}
    end
  end

  @impl true
  def handle_info({:value_update, module, parameter, data_report}, state) do
    [value, qualifiers] = data_report

    timestamp =
      case qualifiers do
        %{t: t} -> t
        %{"t" => t} -> t
        _ -> DateTime.utc_now()
      end

    handle_cast(
      {:parameter_update, module, parameter, value, timestamp, qualifiers},
      state
    )
  end

  @impl true
  def handle_info(:flush_parameter_batch, state) do
    # Schedule the next batch
    schedule_batch_flush()

    # Flush current batch if not empty
    new_state =
      if Enum.empty?(state.parameter_batch) do
        state
      else
        flush_parameter_batch(state)
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("NodeDBWriter received unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    # Flush any remaining parameter values
    unless Enum.empty?(state.parameter_batch) do
      flush_parameter_batch(state)
    end

    Logger.info("Stopping NodeDBWriter for: #{state.equipment_id} (reason: #{inspect(reason)})")
    :ok
  end

  # Private functions

  defp via_tuple(opts) when is_map(opts) do
    {:via, Registry, {Registry.NodeDBWriter, opts[:uuid]}}
  end

  defp via_tuple(uuid) when is_binary(uuid) do
    {:via, Registry, {Registry.NodeDBWriter, uuid}}
  end

  defp schedule_batch_flush do
    Process.send_after(self(), :flush_parameter_batch, @batch_interval)
  end

  defp flush_parameter_batch(state) do
    batch_size = length(state.parameter_batch)
    node_id = state.equipment_id

    if batch_size > 0 do
      Logger.debug("Flushing batch of #{batch_size} parameter values for node #{node_id}")

      # Group by parameter and insert in bulk
      parameter_groups =
        Enum.group_by(
          state.parameter_batch,
          fn {module_name, parameter_name, _, _, _} ->
            {module_name, parameter_name}
          end
        )

      # Process each parameter's values
      Enum.each(parameter_groups, fn {{module_name, parameter_name}, values} ->
        cache_key = {module_name, parameter_name}

        # Process if parameter exists in cache, silently skip if not
        case Map.get(state.parameter_cache, cache_key) do
          nil ->
            # Parameter not in cache, log once and skip
            Logger.warning("Parameter not in cache (skipping): #{module_name}:#{parameter_name}")

          parameter ->
            # Process the parameter values
            insert_parameter_batch(module_name, parameter_name, parameter, values)
        end
      end)

      # Return updated state with empty batch
      %{
        state
        | parameter_batch: [],
          batch_start_time: DateTime.utc_now()
      }
    else
      # No values to flush
      state
    end
  end

  defp insert_parameter_batch(module_name, parameter_name, parameter, values) do
    # Process in transaction using Ecto.Multi for better performance
    multi =
      Enum.reduce(values, Ecto.Multi.new(), fn {_, _, value, timestamp, qualifiers}, multi ->
        # Create the parameter value changeset using the cached parameter
        changeset =
          SecopService.Sec_Nodes.ParameterValue.create_with_parameter(
            value,
            parameter,
            timestamp || DateTime.utc_now(),
            qualifiers || %{}
          )

        # Generate a unique operation name
        name = "val_#{:erlang.unique_integer([:positive])}"
        Ecto.Multi.insert(multi, name, changeset)
      end)

    # Execute the multi operation
    case Repo.transaction(multi) do
      {:ok, _results} ->
        :ok

      {:error, failed_operation, failed_value, _changes_so_far} ->
        Logger.error(
          "Failed to insert parameter values for #{module_name}:#{parameter_name}: #{inspect(failed_operation)} - #{inspect(failed_value)}"
        )
    end
  end

  # Build a cache of full parameter records indexed by {module_name, parameter_name}
  # This is only called once during initialization
  defp build_parameter_cache(node_uuid) do
    # Find the node's parameters
    import Ecto.Query

    parameters =
      from(p in SecopService.Sec_Nodes.Parameter,
        join: m in SecopService.Sec_Nodes.Module,
        on: p.module_id == m.id,
        join: n in SecopService.Sec_Nodes.SEC_Node,
        on: m.sec_node_id == n.uuid,
        where: n.uuid == ^node_uuid,
        preload: [:module]
      )
      |> Repo.all()

    # Build a map of {module_name, parameter_name} => parameter
    Enum.reduce(parameters, %{}, fn parameter, acc ->
      Map.put(acc, {parameter.module.name, parameter.name}, parameter)
    end)
  end
end

defmodule SecopService.NodeDBWriterSupervisor do
  @moduledoc """
  A dynamic supervisor responsible for managing NodeDBWriter processes.

  This supervisor:
  - Creates NodeDBWriter processes for each active SEC node
  - Ensures clean shutdown when nodes disconnect
  - Allows for runtime creation and termination of writers
  - Provides functions to manage NodeDBWriter lifecycle
  """

  use DynamicSupervisor
  require Logger
  alias SecopService.NodeDBWriter

  # Client API

  @doc """
  Starts the NodeDBWriterSupervisor.
  """
  def start_link(init_arg \\ []) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Starts a NodeDBWriter for a node with the given state.

  ## Parameters

    * `node_state` - A map containing the node configuration:
      * `:uuid` - The node's UUID
      * `:equipment_id` - The node's equipment ID
      * `:host` - The node's host address
      * `:port` - The node's port number
      * Other relevant node data

  ## Returns

    * `{:ok, pid}` - The PID of the started NodeDBWriter
    * `{:error, reason}` - If the NodeDBWriter could not be started
  """
  def start_writer(node_state) do
    # Create a specification for the child
    child_spec = %{
      id: NodeDBWriter,
      start: {NodeDBWriter, :start_link, [node_state]},
      # Don't restart if it terminates normally
      restart: :transient,
      shutdown: 5000
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Started NodeDBWriter for #{node_state.equipment_id} (#{node_state.uuid})")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info("NodeDBWriter already started for #{node_state.uuid}")
        {:ok, pid}

      {:error, reason} = error ->
        Logger.error("Failed to start NodeDBWriter for #{node_state.uuid}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Terminates the NodeDBWriter for the given node UUID.

  ## Parameters

    * `node_uuid` - The UUID of the node whose writer should be terminated

  ## Returns

    * `:ok` - If the writer was terminated or wasn't running
    * `{:error, :not_found}` - If no writer for this UUID was found
  """
  def stop_writer(node_uuid) do
    case get_writer_pid(node_uuid) do
      nil ->
        Logger.info("No NodeDBWriter found for UUID #{node_uuid}")
        {:error, :not_found}

      pid ->
        Logger.info("Stopping NodeDBWriter for UUID #{node_uuid}")
        DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  @doc """
  Get the PID of the NodeDBWriter for the given node UUID, if running.

  ## Parameters

    * `node_uuid` - The UUID of the node

  ## Returns

    * `pid` - The PID of the running NodeDBWriter
    * `nil` - If no writer is running for this UUID
  """
  def get_writer_pid(node_uuid) do
    case Registry.lookup(Registry.NodeDBWriter, node_uuid) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc """
  Checks if a NodeDBWriter for the given node UUID is running.

  ## Parameters

    * `node_uuid` - The UUID of the node

  ## Returns

    * `true` - If a writer is running for this UUID
    * `false` - If no writer is running for this UUID
  """
  def writer_exists?(node_uuid) do
    get_writer_pid(node_uuid) != nil
  end

  @doc """
  Gets a list of all running NodeDBWriter UUIDs.

  ## Returns

    * A list of node UUIDs for which writers are running
  """
  def list_writer_uuids do
    Registry.select(Registry.NodeDBWriter, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Count of currently running NodeDBWriter processes.

  ## Returns

    * Integer count of running writers
  """
  def count_writers do
    DynamicSupervisor.count_children(__MODULE__).active
  end

  # Supervisor callbacks

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 60
    )
  end
end
