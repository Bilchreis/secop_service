
defmodule SecopServiceWeb.DashboardLive.Model do

  alias SEC_Node_Statem

  def get_initial_model() do

    active_nodes = get_active_nodes()

    # Get an arbitrary entry from the active_nodes map
    {current_node_key, current_node_value} = Map.to_list(active_nodes) |> List.first()

    # Get an arbitrary module from the current_node's description
    {current_module_key, _current_module_value} = current_node_value[:description][:modules] |> Map.to_list() |> List.first()



    initial_active_nodes = Enum.reduce(active_nodes, %{}, fn {node_id, node} , acc ->
      Map.put(acc,node_id,update_node_values(node, nil))
    end)

    model = %{
      active_nodes: initial_active_nodes,
      current_node_key: current_node_key,
      current_module_key: current_module_key,
    }

    # IO.inspect(model)
    model
  end



  def set_new_current_node(model, new_node_id) do
    model = %{model | current_node_key: new_node_id}

    model
  end


  def get_current_node(model) do
    current_node = model.active_nodes[model.current_node_key]

    current_node
  end

  def set_state(model,node_id,state) do
    model = put_in(model,[:active_nodes,node_id,:state],state)

    model
  end







  defp get_active_nodes() do
    Supervisor.which_children(SEC_Node_Supervisor)
    |> Enum.reduce(%{}, fn {_id, pid, _type, _module}, acc ->
      case SEC_Node_Statem.get_state(pid) do
        {:ok, state} ->
          node_id = state.node_id

          Map.put(acc, node_id, state)

        _ ->
          acc
      end
    end)
  end

  def update_model_values(model, values_map) do
    curr_node_key = model.current_node_key
    current_node = model[:active_nodes][curr_node_key]

    updated_node = update_node_values(current_node, values_map)

    updated_model = put_in(model,[:active_nodes,curr_node_key],updated_node)

    updated_model
  end

  def update_node_values(node, values_map) do


    modules =
      Enum.reduce(node[:description][:modules], %{}, fn {module_name, module_description}, acc ->
        parameters = Enum.reduce(module_description[:parameters], %{}, fn {parameter_name, parameter_description}, param_acc ->
          new_val = case values_map do
            nil -> nil
            _ -> Map.get(values_map, module_name) |> Map.get(parameter_name)

          end

          new_param_description = update_param_descr(new_val, parameter_name, parameter_description)


          updated_param_acc = Map.put(param_acc, parameter_name, new_param_description)

          updated_param_acc
        end)

        Map.put(acc, module_name, Map.put(module_description, :parameters, parameters))
      end)


    updated_node = put_in(node[:description][:modules], modules)


    updated_node
  end

  defp update_param_descr(new_val, parameter_name, parameter_description) do
    new_parameter_description = Map.put(parameter_description,:value,new_val)

    new_keys = case parameter_name do
      :status -> parse_status(new_parameter_description)
      _ -> %{}
    end

    Map.merge(new_parameter_description, new_keys)

  end


  defp parse_status(status) do
    statmap =
      case status.value do
        nil -> %{stat_code: "stat_code", stat_string: "stat_string", status_color: "bg-gray-500"}
        [[stat_code, stat_string] | _rest] ->
          %{
            stat_code: stat_code_lookup(stat_code, status.datainfo),
            stat_string: stat_string,
            status_color: stat_code_to_color(stat_code)
          }
      end

    statmap
  end

  defp stat_code_lookup(stat_code, status_datainfo) do
    status_datainfo.members
    |> Enum.find(fn member -> member.type == "enum" end)
    |> case do
      %{members: members} ->
        members
        |> Enum.find(fn {_key, value} -> value == stat_code end)
        |> case do
          {key, _value} -> key
          nil -> :unknown
        end
      _ -> :unknown
    end
  end

  defp stat_code_to_color(stat_code) do
    cond do
      0 <= stat_code and stat_code < 100 -> "bg-gray-500" # Disabled
      100 <= stat_code and stat_code < 200 -> "bg-green-500" # IDLE
      200 <= stat_code and stat_code < 300 -> "bg-yellow-500" # WARNING
      300 <= stat_code and stat_code < 400 -> "bg-orange-500" # BUSY
      400 <= stat_code and stat_code < 500 -> "bg-red-500" # ERROR
      true -> "bg-white"
    end
  end




end
