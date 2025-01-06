defmodule SecopServiceWeb.DashboardLive.Index do
  use SecopServiceWeb, :live_view

  alias SecopServiceWeb.DashboardLive.Model
  alias SecopClient
  require Logger


  import SECoPComponents

  @impl true
  def mount(_params, _session, socket) do
    model = SecopServiceWeb.DashboardLive.Model.get_initial_model()
    Phoenix.PubSub.subscribe(:secop_parameter_pubsub,model.current_node.pubsub_topic)


    socket = assign(socket, :model, model)


    {:ok, socket}
  end

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
    Phoenix.PubSub.unsubscribe(:secop_parameter_pubsub,socket.assigns.model.current_node.pubsub_topic)
    new_node_id = pubsubtopic_to_node_id(new_pubsub_topic)


    new_model = SecopServiceWeb.DashboardLive.Model.set_new_current_node(socket.assigns.model, new_node_id)

    socket = assign(socket, :model, new_model)

    Phoenix.PubSub.subscribe(:secop_parameter_pubsub,socket.assigns.model.current_node.pubsub_topic)


    {:noreply, socket}
  end




  defp update_values(current_node, values_map) do
    modules =
      Enum.reduce(current_node[:description][:modules], %{}, fn {module_name, module_description}, acc ->
        parameters = Enum.reduce(module_description[:parameters], %{}, fn {parameter_name, parameter_description}, param_acc ->
          new_val = Map.get(values_map, module_name) |> Map.get(parameter_name)

          updated_param_acc =
            if new_val do
              new_param_description = Map.put(parameter_description, :value, new_val)
              Map.put(param_acc, parameter_name, new_param_description)
            else
              Logger.warning("No value found for #{module_name}.#{parameter_name}")
              param_acc
            end

          updated_param_acc
        end)

        Map.put(acc, module_name, Map.put(module_description, :parameters, parameters))
      end)


    current_node = put_in(current_node[:description][:modules], modules)

    current_node
  end


  defp pubsubtopic_to_node_id(pubsub_topic) do
    [ip, port] = String.split(pubsub_topic, ":")
    {String.to_charlist(ip), String.to_integer(port)}
  end

end
