defmodule SecopService.NodeManager do
  use GenServer
  require Logger
  alias SecopService.NodeSupervisor
  alias SecopService.Sec_Nodes
  alias SEC_Node_Supervisor
  alias SecopService.NodeSupervisor


  @pubsub_name :secop_client_pubsub
  # Check for node changes every minute
  @check_interval  1000 * 10 * 60

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_stored_nodes do
    GenServer.call(__MODULE__, :get_stored_nodes)
  end

  def sync_nodes do
    GenServer.cast(__MODULE__, :sync_nodes)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Initial sync of nodes from SEC_Node_Supervisor
    Phoenix.PubSub.subscribe(@pubsub_name, "descriptive_data_change")
    Phoenix.PubSub.subscribe(@pubsub_name, "new_node")

    send(self(), :sync_nodes)
    {:ok, %{nodes: %{}, subscriptions: %{}}}
  end

  @impl true
  def handle_call(:get_stored_nodes, _from, state) do
    {:reply, state.nodes, state}
  end

  @impl true
  def handle_cast(:sync_nodes, state) do
    Logger.info("Syncing nodes with database...")
    # Get active nodes from supervisor
    active_nodes = SEC_Node_Supervisor.get_active_nodes()

    # Store nodes in database and subscribe to updates
    updated_state = sync_nodes_with_db(active_nodes, state)

    # Schedule next sync
    schedule_sync()

    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:sync_nodes, state) do
    # Same as handle_cast but triggered by timer
    handle_cast(:sync_nodes, state)
  end

  def handle_info({:conn_state, _pubsub_topic, _active}, state) do
    # TODO

    {:noreply, state}
  end

  def handle_info({:state_change, pubsub_topic, _node_state}, state) do
    Logger.info("new node status: #{pubsub_topic} #{state.state}")

    {:noreply, state}
  end

  def handle_info({:new_node, _pubsub_topic, :connection_failed}, state) do

    {:noreply, state}
  end

  def handle_info({:new_node, _pubsub_topic, node_state}, state) do
    Logger.info("New node: #{node_state.equipment_id} #{node_state.host} (#{node_state.port})")

    handle_cast(:sync_nodes, state)
    {:noreply, state}
  end

  def handle_info({:description_change, _pubsub_topic, node_state}, state) do
    # Handle node description changes
    Logger.info("Description Change for node: #{node_state.equipment_id}")

    # Find the old UUID if present
    old_uuid = find_old_uuid(state.nodes, node_state.node_id)

    # If we have an old UUID and it's different, stop the old writer
    state =
      if old_uuid && old_uuid != node_state.uuid do
        Logger.info("Node UUID changed from #{old_uuid} to #{node_state.uuid}, stopping node Services")
        NodeSupervisor.stop_node_services(node_state.node_id)

        # Store the new node configuration
        {:ok, db_node} = Sec_Nodes.store_single_node(node_state)

        Logger.debug("publish new node added at: #{db_node.uuid}")

        Phoenix.PubSub.broadcast(
          :secop_client_pubsub,
          "new_node",
          {:new_node_db, db_node}
        )


        updated_nodes = Map.put(state.nodes, node_state.node_id, node_state)
        # Start a new writer
        NodeSupervisor.start_child(Sec_Nodes.get_sec_node_by_uuid(node_state.uuid))
        %{state | nodes: updated_nodes}
      else
        state
      end

    {:noreply, state}
  end

  # Helper to find a node's old UUID
  defp find_old_uuid(nodes, node_id) do
    Map.get(nodes, node_id)
    |> case do
      nil -> nil
      node -> node.uuid
    end
  end

  # Private functions

  defp schedule_sync do
    Process.send_after(self(), :sync_nodes, @check_interval)
  end

  defp sync_nodes_with_db(active_nodes, state) do
    # Store nodes in database


    result =
      Enum.reduce(active_nodes, %{}, fn {node_id, node_state}, acc ->
        case Sec_Nodes.node_exists?(node_state.uuid) do
          false ->
            # New node
            Logger.info(
              "New node: #{node_state.equipment_id} #{node_state.host}:#{node_state.port}"
            )

            {:ok, _node} = Sec_Nodes.store_single_node(node_state)

            Map.put(acc, node_id, node_state)

          true ->
            acc
        end
      end)

    # Start node Services for active nodes that don't have one
    Enum.each(active_nodes, fn {_node_id, node_state} ->
      if not NodeSupervisor.services_running?(node_state.node_id) do
        Logger.info("Starting Services for node: #{node_state.equipment_id} #{node_state.host}:#{node_state.port}")
        NodeSupervisor.start_child(Sec_Nodes.get_sec_node_by_uuid(node_state.uuid))
      end
    end)

    # Stop Node Services for nodes that are no longer active
    active_node_ids = active_nodes |> Enum.map(fn {_, node} -> node.node_id end) |> MapSet.new()
    current_service_node_ids = NodeSupervisor.list_node_id_services() |> MapSet.new()

    # Writers to stop: those that exist but aren't in active nodes
    MapSet.difference(current_service_node_ids, active_node_ids)
    |> Enum.each(fn node_id ->
      NodeSupervisor.stop_node_services(node_id)
    end)

    old_nodes = state.nodes

    # Update statenode
    merged_nodes =
      Map.merge(old_nodes, result, fn _key, new_node, _old_node -> new_node end)
      |> keep_common_keys(active_nodes)

    %{state | nodes: merged_nodes}
  end

  defp keep_common_keys(map1, map2) do
    Map.filter(map1, fn {key, _value} -> Map.has_key?(map2, key) end)
  end
end
