defmodule SecopServiceWeb.DashboardLive.Index do
  use SecopServiceWeb, :live_view

  alias SecopServiceWeb.DashboardLive.Model, as: Model
  alias SecopServiceWeb.NodeControl
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
    Loggerl.info("Description Change")
    {:noreply, socket}
  end

  def handle_info({:conn_state, _pubsub_topic, active}, socket) do
    # TODO
    Loggerl.info("conn_state Change #{inspect(active)}")
    {:noreply, socket}
  end

  # Handle Plot updates
  def handle_info({host, port, module, parameter, {:plot_data, plot_data}}, socket) do
    updated_model =
      Model.update_plot(socket.assigns.model, {host, port}, module, parameter, plot_data)


    socket = update_chart_data(socket,{host,port},module,parameter)
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

  def handle_event("set_parameter", unsigned_params, socket) do
    Logger.info("Setting parameter #{unsigned_params["parameter"]} to #{unsigned_params["value"]}")

    NodeControl.change(unsigned_params)

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

  @impl true
  def handle_event("request-plotly-data", %{"id" => chart_id}, %{assigns: assigns} = socket) do
    # Use chart_id to determine which chart is requesting data


    path = case String.split(chart_id, ":") do
      ["plotly",host,port,module,parameter] -> [{String.to_charlist(host),String.to_integer(port)},:description,:modules,String.to_atom(module),:parameters,String.to_atom(parameter),:plot]
      ["plotly",host,port,module] -> [{String.to_charlist(host),String.to_integer(port)},:description,:modules,String.to_atom(module),:plot]
     end

    plot = get_in(assigns.model.active_nodes,path)

    {data, layout, config} = plot.plotly

    {:noreply, push_event(socket, "plotly-data", %{
      id: chart_id,
      data: data,
      layout: layout,
      config: config
    })}
  end

  # For real-time updates to a specific chart
  def update_chart_data(socket,node_id, module, parameter) do

    model = socket.assigns.model

    {chart_id,plotly} = Model.get_module_plot_data(model,node_id,module)




    socket = if plotly do

      {data, layout, config} = plotly

      push_event(socket, "plotly-update", %{
        id: chart_id,
        data: data,
        layout: layout,
        config: config
      })
      else
      socket
    end
    socket

  end


end
