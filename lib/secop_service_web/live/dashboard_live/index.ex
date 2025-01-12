defmodule SecopServiceWeb.DashboardLive.Index do
  use SecopServiceWeb, :live_view

  alias SecopServiceWeb.DashboardLive.Model
  alias SecopClient
  require Logger


  import SECoPComponents

  @impl true
  def mount(_params, _session, socket) do
    model = SecopServiceWeb.DashboardLive.Model.get_initial_model()
    Phoenix.PubSub.subscribe(:secop_client_pubsub,model.current_node.pubsub_topic)
    Phoenix.PubSub.subscribe(:secop_client_pubsub,"descriptive_data_change")
    Phoenix.PubSub.subscribe(:secop_client_pubsub,"state_change")
    Phoenix.PubSub.subscribe(:secop_client_pubsub,"secop_conn_state")
    Phoenix.PubSub.subscribe(:secop_client_pubsub,"new_node")


    model = Map.put(model,:current_node,update_values(model.current_node, nil))

    active_nodes = Enum.reduce(model.active_nodes, %{}, fn {node_id, node} , acc ->
      Map.put(acc,node_id,update_values(node, nil))
    end)

    model = Map.put(model,:active_nodes,active_nodes)


    socket = assign(socket, :model, model)


    {:ok, socket}
  end


  ### New Values Map Update
  @impl true
  def handle_info({:values_map,pubsub_topic,values_map}, socket) do
    socket =
      if pubsub_topic == socket.assigns.model.current_node.pubsub_topic do
        new_current_node = update_values(socket.assigns.model.current_node,values_map)
        assign(socket, :model, Map.put(socket.assigns.model, :current_node, new_current_node))
      end


    {:noreply, socket}
  end

  @impl true
  def handle_event("node-select", %{"pubsubtopic" => new_pubsub_topic}, socket) do
    Phoenix.PubSub.unsubscribe(:secop_client_pubsub,socket.assigns.model.current_node.pubsub_topic)
    new_node_id = pubsubtopic_to_node_id(new_pubsub_topic)


    new_model = SecopServiceWeb.DashboardLive.Model.set_new_current_node(socket.assigns.model, new_node_id)

    socket = assign(socket, :model, new_model)

    Phoenix.PubSub.subscribe(:secop_client_pubsub,socket.assigns.model.current_node.pubsub_topic)


    {:noreply, socket}
  end




  defp update_values(current_node, values_map) do
    modules =
      Enum.reduce(current_node[:description][:modules], %{}, fn {module_name, module_description}, acc ->
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


    current_node = put_in(current_node[:description][:modules], modules)


    current_node
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



  defp pubsubtopic_to_node_id(pubsub_topic) do
    [ip, port] = String.split(pubsub_topic, ":")
    {String.to_charlist(ip), String.to_integer(port)}
  end

end
