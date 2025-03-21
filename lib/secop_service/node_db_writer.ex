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
      name: via_tuple(opts[:node_id])
    )
  end

  def update_parameter(node_id, module_name, parameter_name, value, timestamp, qualifiers) do
    GenServer.cast(via_tuple(node_id), {:parameter_update, module_name, parameter_name, value, timestamp, qualifiers})
  end



  # Server callbacks

  @impl true
  def init(node_data) do
    # Subscribe to node's topic for parameter updates
    topic = "value_update:#{node_data.equipment_id}"
    Phoenix.PubSub.subscribe(@pubsub_name, topic)

    Logger.info("Started node handler for: #{node_data.equipment_id} (#{node_data.uuid})")

    # Start batch flush timer
    schedule_batch_flush()

    {:ok, %{
      node_data: node_data,
      parameter_batch: [],
      batch_start_time: DateTime.utc_now()
    }}
  end

  @impl true
  def handle_cast({:parameter_update, module_name, parameter_name, value, timestamp, qualifiers}, state) do
    # Add to batch
    updated_batch = [{module_name, parameter_name, value, timestamp, qualifiers} | state.parameter_batch]

    # Check if we need to flush based on size
    if length(updated_batch) >= @max_batch_size do
      new_state = flush_parameter_batch(%{state | parameter_batch: updated_batch})
      {:noreply, new_state}
    else
      {:noreply, %{state | parameter_batch: updated_batch}}
    end
  end

  @impl true
  def handle_info({:parameter_value, parameter_path, value, timestamp, qualifiers}, state) do
    # Extract module and parameter from path (format: "module:parameter")
    case String.split(parameter_path, ":", parts: 2) do
      [module_name, parameter_name] ->
        # Handle the parameter update
        handle_cast(
          {:parameter_update, module_name, parameter_name, value, timestamp, qualifiers},
          state
        )
      _ ->
        Logger.warning("Invalid parameter path format: #{parameter_path}")
        {:noreply, state}
    end
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
    Logger.debug("NodeHandler received unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    # Flush any remaining parameter values
    unless Enum.empty?(state.parameter_batch) do
      flush_parameter_batch(state)
    end

    Logger.info("Stopping node handler for: #{state.node_data.equipment_id} (reason: #{inspect(reason)})")
    :ok
  end

  # Private functions

  defp via_tuple(node_uuid) do
    {:via, Registry, {Registry.NodeDBWriter, {opts[:host], opts[:port]}}}
  end

  defp schedule_batch_flush do
    Process.send_after(self(), :flush_parameter_batch, @batch_interval)
  end

  defp flush_parameter_batch(state) do
    batch_size = length(state.parameter_batch)
    node_id = state.node_data.equipment_id

    if batch_size > 0 do
      Logger.debug("Flushing batch of #{batch_size} parameter values for node #{node_id}")

      # Group by parameter and insert in bulk
      parameter_groups = Enum.group_by(state.parameter_batch,
        fn {module_name, parameter_name, _, _, _} ->
          {module_name, parameter_name}
        end)

      # Process each parameter's values in transaction
      Enum.each(parameter_groups, fn {{module_name, parameter_name}, values} ->
        insert_parameter_batch(node_id, module_name, parameter_name, values)
      end)
    end

    # Reset batch
    %{state | parameter_batch: [], batch_start_time: DateTime.utc_now()}
  end

  defp insert_parameter_batch(node_id, module_name, parameter_name, values) do
    # Look up the parameter (just once per batch)
    case find_parameter_by_path(node_id, module_name, parameter_name) do
      {:ok, parameter} ->
        # Process in transaction using Ecto.Multi for better performance
        multi =
          Enum.reduce(values, Ecto.Multi.new(), fn {_, _, value, timestamp, qualifiers}, multi ->
            # Create the parameter value changeset
            changeset = SecopService.Sec_Nodes.ParameterValue.create_with_parameter(
              value, parameter, timestamp, qualifiers)

            # Generate a unique operation name
            name = "val_#{:erlang.unique_integer([:positive])}"
            Ecto.Multi.insert(multi, name, changeset)
          end)

        # Execute the multi operation
        case Repo.transaction(multi) do
          {:ok, _results} ->
            :ok
          {:error, failed_operation, failed_value, _changes_so_far} ->
            Logger.error("Failed to insert parameter values for #{node_id}:#{module_name}:#{parameter_name}: #{inspect(failed_operation)} - #{inspect(failed_value)}")
        end

      {:error, reason} ->
        Logger.error("Failed to find parameter #{node_id}:#{module_name}:#{parameter_name}: #{reason}")
    end
  end

  defp find_parameter_by_path(node_id, module_name, parameter_name) do
    # Query to find parameter by path components
    import Ecto.Query

    parameter =
      from(p in SecopService.Sec_Nodes.Parameter,
        join: m in SecopService.Sec_Nodes.Module, on: p.module_id == m.id,
        join: n in SecopService.Sec_Nodes.SEC_Node, on: m.sec_node_id == n.uuid,
        where: n.equipment_id == ^node_id and
               m.name == ^module_name and
               p.name == ^parameter_name,
        select: p)
      |> Repo.one()

    if parameter, do: {:ok, parameter}, else: {:error, "Parameter not found"}
  end
end
