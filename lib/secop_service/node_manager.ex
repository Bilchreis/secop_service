defmodule SecopService.NodeManager do
  use GenServer
  require Logger
  alias SecopService.Sec_Nodes
  alias SecopService.Repo
  alias Phoenix.PubSub
  alias SEC_Node_Supervisor

  @pubsub_name :secop_client_pubsub
  @check_interval 10 * 60 * 1000 # Check for node changes every minute

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

  @impl true
  def handle_info({:description_change, _pubsub_topic, _state}, state) do
    # TODO
    Logger.info("Description Change")
    {:noreply, state}
  end

  def handle_info({:conn_state, _pubsub_topic, active}, state) do
    # TODO
    Logger.info("conn_state Change #{inspect(active)}")
    {:noreply, state}
  end

  def handle_info({:state_change, pubsub_topic, node_state}, state) do
    Logger.info("new node status: #{pubsub_topic} #{state.state}")


    {:noreply, state}
  end

  def handle_info({:new_node, _pubsub_topic, node_state}, state) do
    Logger.info("New node: #{node_state.equipment_id} #{node_state.host} (#{node_state.port})")

    handle_cast(:sync_nodes, state)
    {:noreply, state}
  end




  # Private functions

  defp schedule_sync do
    Process.send_after(self(), :sync_nodes, @check_interval)
  end

  defp sync_nodes_with_db(active_nodes, state) do
    # Store nodes in database

    result = Enum.reduce(active_nodes, %{}, fn {node_id, node_state}, acc ->
      case Sec_Nodes.node_exists?(node_state.uuid) do
        false ->
          # New node
          Logger.info("New node: #{node_state.equipment_id} #{node_state.host}:#{node_state.port}")

          Map.put(acc, node_id, Sec_Nodes.store_single_node(node_state))
        true ->
          # Update existing node
          Logger.info("Node already in db: #{node_state.equipment_id} #{node_state.host}:#{node_state.port}")
          acc
      end
    end)

    saved_nodes = state.nodes

    # Update state
    merged_nodes =
      Map.merge(saved_nodes, result, fn _key, new_node, old_node -> new_node end)
      |> keep_common_keys(active_nodes)


    %{state | nodes: merged_nodes}

  end

  defp keep_common_keys(map1, map2) do
    Map.filter(map1, fn {key, _value} -> Map.has_key?(map2, key) end)
  end




end
