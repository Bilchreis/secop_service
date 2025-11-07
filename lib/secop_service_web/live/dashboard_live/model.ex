defmodule SecopServiceWeb.DashboardLive.Model do
  require Logger
  alias SEC_Node_Supervisor
  use Phoenix.Component

  alias NodeTable
  alias SecopService.NodeValues
  alias SecopService.NodeSupervisor

  def get_initial_model() do
    active_nodes = SEC_Node_Supervisor.get_active_nodes()

    # Select only the relevant keys from each node
    active_nodes =
      Enum.reduce(active_nodes, %{}, fn {node_id, node}, acc ->
        node =
          Map.take(node, [
            :host,
            :port,
            :node_id,
            :equipment_id,
            :pubsub_topic,
            :state,
            :active,
            :uuid,
            :error
          ])

        Map.put(acc, node_id, node)
      end)

    model =
      if active_nodes == %{} do
        %{active_nodes: %{}, current_node: nil, values: nil}
      else
        # Get an arbitrary entry from the active_nodes map
        {_current_node_key, current_node_state} = Map.to_list(active_nodes) |> List.first()
        current_node_id = current_node_state[:node_id]

        current_node =
          if NodeSupervisor.services_running?(current_node_id) do
            {:ok, node_db} = NodeValues.get_node_db(current_node_id)
            node_db
          end

        {:ok, values} = NodeValues.get_values(current_node_id)

        %{
          active_nodes: active_nodes,
          current_node: current_node,
          values: values
        }
      end

    model
  end

  def set_current_node(model, node_id) do
    current_node = Map.get(model.active_nodes, node_id)

    # Get the current node from the active nodes map
    model =
      if NodeSupervisor.services_running?(node_id) do
        {:ok, db_node} = NodeValues.get_node_db(node_id)

        {:ok, values} = NodeValues.get_values(node_id)

        model =
          model
          |> Map.put(:current_node, db_node)
          |> Map.put(:values, values)

        model
      else
        Logger.warning("Services for Node with UUID #{current_node[:uuid]} are not running yet.")
        model
      end

    model
  end
end
