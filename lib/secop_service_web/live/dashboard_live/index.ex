defmodule SecopServiceWeb.DashboardLive.Index do
  use SecopServiceWeb, :live_view

  alias SecopServiceWeb.DashboardLive.Model, as: Model
  alias SecopClient
  require Logger

  import SECoPComponents

  @impl true
  def mount(_params, _session, socket) do
    model = Model.get_initial_model()

    curr_node_key = model.current_node_key

    values_pubsub_topic = model[:active_nodes][curr_node_key][:pubsub_topic]

    Phoenix.PubSub.subscribe(:secop_client_pubsub, values_pubsub_topic)
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "descriptive_data_change")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "state_change")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "secop_conn_state")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "new_node")

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

  def handle_info({:description_change, pubsub_topic, state}, socket) do
    {:noreply, socket}
  end

  def handle_info({:conn_state, pubsub_topic, active}, socket) do
    {:noreply, socket}
  end

  def handle_info({:state_change, pubsub_topic, new_state}, socket) do
    Logger.debug("new node status: #{pubsub_topic} #{new_state}")

    updated_model =
      Model.set_state(
        socket.assigns.model,
        pubsubtopic_to_node_id(pubsub_topic),
        new_state
      )

    {:noreply, assign(socket, :model, updated_model)}
  end

  def handle_info({:new_node, pubsub_topic, state}, socket) do
    {:noreply, socket}
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
