defmodule SecopService.NodeDBWriter do
  use GenServer
  require Logger

  alias SecopService.Repo
  alias SecopService.Sec_Nodes.SEC_Node

  @pubsub_name :secop_client_pubsub
  # Batch parameter values for 5 seconds
  @batch_interval 10_000
  # Safety limit for batch size
  @max_batch_size 1000

  # Client API

  def start_link(node_db) do
    GenServer.start_link(__MODULE__, node_db,
      name: {:via, Registry, {Registry.NodeDBWriter, SEC_Node.get_node_id(node_db)}}
    )
  end

  def update_parameter(node_id, module, parameter, data_report) do
    [{sec_node_pid, _value}] = Registry.lookup(Registry.NodeDBWriter, node_id)
    GenServer.cast(sec_node_pid, {:parameter_update, module, parameter, data_report})
  end

  # Server callbacks

  @impl true
  def init(node_db) do
    # Subscribe to node's topic for parameter updates
    topic = SEC_Node.get_values_pubsub_topic(node_db)
    Phoenix.PubSub.subscribe(@pubsub_name, topic)

    Logger.info("Started DB writer for Node: #{node_db.equipment_id} (#{node_db.uuid})")

    # Build parameter cache with full parameter records once at startup
    parameter_cache = build_parameter_cache(node_db.uuid)

    # Log cache stats
    cache_size = map_size(parameter_cache)

    Logger.info(
      "Built parameter cache for node #{node_db.equipment_id} with #{cache_size} parameters"
    )

    # Start batch flush timer
    schedule_batch_flush()

    {:ok,
     %{
       host: node_db.host,
       port: node_db.port,
       equipment_id: node_db.equipment_id,
       uuid: node_db.uuid,
       parameter_batch: [],
       batchsize: 0,
       # Cache of full parameter records (built once, never updated)
       parameter_cache: parameter_cache
     }}
  end

  @impl true
  def handle_cast({:parameter_update, module, parameter, value, timestamp, qualifiers}, state) do
    case Map.get(state.parameter_cache, {module, parameter}) do
      nil ->
        # Parameter not in cache, log once and skip
        Logger.warning("Parameter not in cache (skipping): #{module}:#{parameter}")

        {:noreply, state}



      parameter_db ->
        # Process the parameter values

        now = DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
        param_val_map = SecopService.Sec_Nodes.ParameterValue.create_raw_with_parameter(
                value,
                parameter_db,
                timestamp || DateTime.utc_now(),
                qualifiers || %{}
              )
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)


        batchsize = state.batchsize + 1
            # Add to batch
        updated_batch = [param_val_map | state.parameter_batch]

        # Check if we need to flush based on size
        if batchsize >= @max_batch_size do
          insert_parameter_batch(updated_batch)
          {:noreply, %{state | parameter_batch: [], batchsize: 0}}
        else
          {:noreply, %{state | parameter_batch: updated_batch, batchsize: batchsize}}
        end
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
        insert_parameter_batch(state.parameter_batch)
        %{state | parameter_batch: [], batchsize: 0}
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
      insert_parameter_batch(state.parameter_batch)
    end

    Logger.info("Stopping NodeDBWriter for: #{state.equipment_id} (reason: #{inspect(reason)})")
    :ok
  end

  defp schedule_batch_flush do
    Process.send_after(self(), :flush_parameter_batch, @batch_interval)
  end


  defp insert_parameter_batch(batch) do

    Task.start(fn ->
      {count, _} = Repo.insert_all(
        SecopService.Sec_Nodes.ParameterValue,
        batch
      )

      Logger.debug("Successfully inserted #{count} parameter values")
    end)

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
