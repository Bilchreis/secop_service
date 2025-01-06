alias SecopClient


defmodule SecopServiceWeb.DashboardLive.Model do
  def get_initial_model() do
    active_nodes = SecopClient.get_active_nodes()

    # Get an arbitrary entry from the active_nodes map
    {current_node_key, current_node_value} = Map.to_list(active_nodes) |> List.first()

    # Get an arbitrary module from the current_node's description
    {current_module_key, current_module_value} = current_node_value[:description][:modules] |> Map.to_list() |> List.first()

    model = %{
      active_nodes: active_nodes,
      current_node: current_node_value,
      current_module:  current_module_value,
      current_node_key: current_node_key,
      current_module_key: current_module_key,
    }

    # IO.inspect(model)
    model
  end



  def set_new_current_node(model, new_node_id) do



    model = put_in(model,[:active_nodes,model.current_node.node_id], model.current_node)



    new_current_node = model.active_nodes |> Map.get(new_node_id)



    model = Map.put(model, :current_node, new_current_node)
    model
  end



end
