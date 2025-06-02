defmodule SecopServiceWeb.DashboardLive.Index do
  alias SecopServiceWeb.BrowseComponents
  alias Phoenix.Socket.Broadcast
  alias SecopService.Sec_Nodes.SEC_Node
  use SecopServiceWeb, :live_view

  alias SecopServiceWeb.DashboardLive.Model, as: Model
  alias SecopServiceWeb.NodeControl
  alias SecopClient
  alias SEC_Node_Supervisor
  alias SEC_Node
  require Logger

  import SECoPComponents
  import SecopServiceWeb.DashboardComponents

  def model_from_socket(socket) do
    model = %{
      active_nodes: socket.assigns.active_nodes,
      current_node: socket.assigns.current_node,
      values: socket.assigns.values
    }
  end

  def model_to_socket(model,socket) do
    socket
    |> assign(:active_nodes, model.active_nodes)
    |> assign(:current_node, model.current_node)
    |> assign(:values, model.values)
  end



  @impl true
  def mount(_params, _session, socket) do
    model = Model.get_initial_model()

    if model.active_nodes == %{} do
      Logger.info("No active nodes detected")
    else
      values_pubsub_topic =
        model[:active_nodes][SEC_Node.get_node_id(model.current_node)][:pubsub_topic]

      Phoenix.PubSub.subscribe(:secop_client_pubsub, "value_update:#{values_pubsub_topic}")
    end

    Phoenix.PubSub.subscribe(:secop_client_pubsub, "descriptive_data_change")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "state_change")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "secop_conn_state")
    Phoenix.PubSub.subscribe(:secop_client_pubsub, "new_node")

    socket =
      socket
      |> assign(:active_nodes, model.active_nodes)
      |> assign(:current_node, model.current_node)
      |> assign(:values, model.values)
      |> assign(:show_connect_modal, false)

    {:ok, socket}
  end

  ### New Values Map Update

  @impl true
  def handle_info({:description_change, _pubsub_topic, _state}, socket) do
    # TODO
    Logger.info("Description Change")
    {:noreply, socket}
  end

  def handle_info({:conn_state, _pubsub_topic, active}, socket) do
    # TODO
    Logger.info("conn_state Change #{inspect(active)}")
    {:noreply, socket}
  end

  def handle_info({:state_change, pubsub_topic, state}, socket) do
    Logger.info("new node status: #{pubsub_topic} #{state.state}")

    {:noreply, socket}
  end

  def handle_info({:new_node, pubsub_topic, state}, socket) do
    Logger.info("new node status: #{pubsub_topic} #{inspect(state)}")

    {:noreply, socket}
  end

  def handle_info({:value_update, pubsub_topic, data_report}, socket) do
    # # Parameter-level plots
    # send_update(SecopServiceWeb.Components.PlotlyChart,
    #   id: "plotly:" <> pubsub_topic,
    #   value_update: data_report,
    #   pubsub_topic: pubsub_topic
    # )

    # # Module-level plots
    # send_update(SecopServiceWeb.Components.PlotlyChart,
    #   id: "plotly:" <> remove_last_segment(pubsub_topic),
    #   value_update: data_report,
    #   pubsub_topic: pubsub_topic
    # )

    {:noreply, socket}
  end

  def handle_info({:value_update, module, "status", data_report}, socket) do

    accessible = "status"

    socket =
      case Model.value_update(socket.assigns.values, module, accessible, data_report) do
        {:ok, :equal, _values} ->
          socket

        {:ok, :updated, values} ->
          send_update(SecopServiceWeb.Components.ModuleIndicator,
            id: "module_indicator:" <> module,
            value_update: data_report
          )
          send_update(SecopServiceWeb.Components.ModuleIndicator,
            id: "module_indicator_mod:" <> module,
            value_update: data_report
          )

          send_update(SecopServiceWeb.Components.ParameterValueDisplay,
            id: "parameter_value:" <> module <> ":" <> accessible,
            value_update: data_report
          )
          assign(socket, :values, values)

        {:error, :parameter_not_found, _values} ->
          Logger.warning("Parameter #{accessible} in module #{module} not found in values")
          socket
      end

    {:noreply, socket}
  end

  def handle_info({:value_update, module, accessible, data_report}, socket) do
    socket =
      case Model.value_update(socket.assigns.values, module, accessible, data_report) do
        {:ok, :equal, _values} ->
          socket

        {:ok, :updated, values} ->
          send_update(SecopServiceWeb.Components.ParameterValueDisplay,
            id: "parameter_value:" <> module <> ":" <> accessible,
            value_update: data_report
          )


          assign(socket, :values, values)

        {:error, :parameter_not_found, _values} ->
          Logger.warning("Parameter #{accessible} in module #{module} not found in values")
          socket
      end

    {:noreply, socket}
  end


  @impl true
  def handle_event("node-select", %{"pstopic" => new_pubsub_topic}, socket) do
    # unsubscribe from the current node's pubsub topic

    current_node = socket.assigns.current_node


    Phoenix.PubSub.unsubscribe(
      :secop_client_pubsub,
      SEC_Node.get_values_pubsub_topic(current_node)
    )



    # subscribe to the new node's pubsub topic & update the model
    new_node_id = pubsubtopic_to_node_id(new_pubsub_topic)
    new_model = model_from_socket(socket) |> Model.set_current_node(new_node_id)
    socket = model_to_socket(new_model, socket)


    Phoenix.PubSub.subscribe(
      :secop_client_pubsub,
      SEC_Node.get_values_pubsub_topic(new_model.current_node)
    )

    {:noreply, socket}
  end

  defp remove_last_segment(topic) do
    parts = String.split(topic, ":")
    parts |> Enum.drop(-1) |> Enum.join(":")
  end

  @impl true
  def handle_event("set_parameter", unsigned_params, socket) do
    Logger.info(
      "Setting parameter #{unsigned_params["parameter"]} to #{unsigned_params["value"]}"
    )

    NodeControl.change(unsigned_params, socket.assigns.model)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_parameter", unsigned_params, socket) do
    Logger.info(
      "validating parameter #{unsigned_params["parameter"]} to #{unsigned_params["value"]}"
    )

    model = NodeControl.validate(unsigned_params, socket.assigns.model)

    {:noreply, assign(socket, :model, model)}
  end

  @impl true
  def handle_event("open_connect_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_connect_modal: true
     )}
  end

  @impl true
  def handle_event("close_connect_modal", _params, socket) do
    {:noreply, assign(socket, show_connect_modal: false)}
  end

  def handle_event("connect-node", params, socket) do
    opts = %{
      host: params["host"] |> String.to_charlist(),
      port: params["port"] |> String.to_integer(),
      reconnect_backoff: 5000
    }

    SEC_Node_Supervisor.start_child(opts)
    {:noreply, socket}
  end

  defp pubsubtopic_to_node_id(pubsub_topic) do
    [ip, port] = String.split(pubsub_topic, ":")
    {String.to_charlist(ip), String.to_integer(port)}
  end
end
