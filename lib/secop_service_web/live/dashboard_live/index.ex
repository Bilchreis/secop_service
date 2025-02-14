defmodule SecopServiceWeb.DashboardLive.Index do
  use SecopServiceWeb, :live_view

  alias SecopServiceWeb.DashboardLive.Model, as: Model
  alias SecopClient
  require Logger

  import SECoPComponents

  @impl true
  def mount(_params, _session, socket) do
    model = Model.get_initial_model()

    cond do
      model.active_nodes == %{} ->
        Logger.info("No active nodes detected")

      true ->
        values_pubsub_topic = model[:active_nodes][model.current_node_key][:pubsub_topic]
        Phoenix.PubSub.subscribe(:secop_client_pubsub, values_pubsub_topic)
    end

    Phoenix.PubSub.subscribe(:secop_client_pubsub, "descriptive_data_change")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "state_change")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "secop_conn_state")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "new_node")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "plot")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "spark")

    socket = assign(socket, :model, model)

    {:ok, socket}
  end

  ### New Values Map Update
  @impl true
  def handle_info({:values_map, pubsub_topic, values_map}, socket) do
    current_node = Model.get_current_node(socket.assigns.model)

    socket =
      if pubsub_topic == current_node.pubsub_topic do
        updated_model = Model.update_model_values(socket.assigns.model, values_map)
        assign(socket, :model, updated_model)
      end

    {:noreply, socket}
  end

  def handle_info({:description_change, _pubsub_topic, _state}, socket) do
    # TODO

    {:noreply, socket}
  end

  def handle_info({:conn_state, _pubsub_topic, _active}, socket) do
    # TODO

    {:noreply, socket}
  end

  # handle Sparkline updates
  def handle_info({_host, _port, _module, _parameter, {:spark_data, _svg}}, socket) do
    {:noreply, socket}
  end

  # Handle Plot updates
  def handle_info({host, port, module, parameter, {:plot_data, svg}}, socket) do
    updated_model =
      Model.update_plot(socket.assigns.model, {host, port, module, parameter}, svg)

    {:noreply, assign(socket, :model, updated_model)}
  end

  def handle_info({:state_change, pubsub_topic, state}, socket) do
    Logger.info("new node status: #{pubsub_topic} #{state.state}")

    updated_model =
      Model.set_state(
        socket.assigns.model,
        state
      )

    {:noreply, assign(socket, :model, updated_model)}
  end

  def handle_info({:new_node, _pubsub_topic, state}, socket) do
    updated_model = Model.add_node(socket.assigns.model, state)

    {:noreply, assign(socket, :model, updated_model)}
  end

  @impl true
  def handle_event("node-select", %{"pubsubtopic" => new_pubsub_topic}, socket) do
    current_node = Model.get_current_node(socket.assigns.model)
    Phoenix.PubSub.unsubscribe(:secop_client_pubsub, current_node.pubsub_topic)

    new_node_id = pubsubtopic_to_node_id(new_pubsub_topic)

    new_model = Model.set_new_current_node(socket.assigns.model, new_node_id)

    socket = assign(socket, :model, new_model)

    new_current_node = Model.get_current_node(socket.assigns.model)

    Phoenix.PubSub.subscribe(:secop_client_pubsub, new_current_node.pubsub_topic)

    {:noreply, socket}
  end

  defp pubsubtopic_to_node_id(pubsub_topic) do
    [ip, port] = String.split(pubsub_topic, ":")
    {String.to_charlist(ip), String.to_integer(port)}
  end
end
