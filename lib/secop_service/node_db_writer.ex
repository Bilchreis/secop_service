defmodule SecopService.NodeDBWriter do
  use GenServer
  require Logger
  alias SecopService.Sec_Nodes
  alias SecopService.Repo
  alias Phoenix.PubSub

  @pubsub_name :secop_client_pubsub
  @batch_interval 5_000  # Batch parameter values for 5 seconds
  @max_batch_size 1000   # Safety limit for batch size

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
    Logger.info("Built parameter cache for node #{opts[:equipment_id]} with #{cache_size} parameters")

    # Start batch flush timer
    schedule_batch_flush()

    {:ok, %{
      host: opts[:host],
      port: opts[:port],
      equipment_id: opts[:equipment_id],
      uuid: opts[:uuid],
      node_data: opts[:node_data],
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

    timestamp = case qualifiers do
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
      parameter_groups = Enum.group_by(state.parameter_batch,
        fn {module_name, parameter_name, _, _, _} ->
          {module_name, parameter_name}
        end)

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
        state |
        parameter_batch: [],
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
        changeset = SecopService.Sec_Nodes.ParameterValue.create_with_parameter(
          value, parameter, timestamp || DateTime.utc_now(), qualifiers || %{})

        # Generate a unique operation name
        name = "val_#{:erlang.unique_integer([:positive])}"
        Ecto.Multi.insert(multi, name, changeset)
      end)

    # Execute the multi operation
    case Repo.transaction(multi) do
      {:ok, _results} ->
        :ok
      {:error, failed_operation, failed_value, _changes_so_far} ->
        Logger.error("Failed to insert parameter values for #{module_name}:#{parameter_name}: #{inspect(failed_operation)} - #{inspect(failed_value)}")
    end
  end

  # Build a cache of full parameter records indexed by {module_name, parameter_name}
  # This is only called once during initialization
  defp build_parameter_cache(node_uuid) do
    # Find the node's parameters
    import Ecto.Query

    parameters =
      from(p in SecopService.Sec_Nodes.Parameter,
        join: m in SecopService.Sec_Nodes.Module, on: p.module_id == m.id,
        join: n in SecopService.Sec_Nodes.SEC_Node, on: m.sec_node_id == n.uuid,
        where: n.uuid == ^node_uuid,
        preload: [:module])
      |> Repo.all()

    # Build a map of {module_name, parameter_name} => parameter
    Enum.reduce(parameters, %{}, fn parameter, acc ->
      Map.put(acc, {parameter.module.name, parameter.name}, parameter)
    end)
  end
end
