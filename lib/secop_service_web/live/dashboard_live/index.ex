defmodule SecopServiceWeb.DashboardLive.Index do
  alias SecopService.Sec_Nodes.SEC_Node
  use SecopServiceWeb, :live_view

  alias SecopServiceWeb.DashboardLive.Model, as: Model
  alias SecopClient
  alias NodeDiscover
  alias SEC_Node_Supervisor
  alias SEC_Node
  alias SecopService.Sec_Nodes
  require Logger

  alias SEC_Node_Statem
  import SECoPComponents
  import SecopServiceWeb.DashboardComponents

  def model_from_socket(socket) do
    %{
      active_nodes: socket.assigns.active_nodes,
      current_node: socket.assigns.current_node,
      values: socket.assigns.values
    }
  end

  def model_to_socket(model, socket) do
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

      Phoenix.PubSub.subscribe(:secop_client_pubsub, "error_update:#{values_pubsub_topic}")

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
  def handle_info({:description_change, pubsub_topic, state}, socket) do
    Logger.info("node state change: #{pubsub_topic} #{state.state}")

    node_id = pubsubtopic_to_node_id(pubsub_topic)

    updated_node =
      socket.assigns.active_nodes[node_id]
      |> Map.put(:description, state.description)
      |> Map.put(:equipment_id, state.equipment_id)
      |> Map.put(:raw_description, state.raw_description)
      |> Map.put(:uuid, state.uuid)

    active_nodes = socket.assigns.active_nodes |> Map.put(node_id, updated_node)
    current_node = socket.assigns.current_node
    values = socket.assigns.values

    socket =
      cond do
        current_node == nil ->
          Logger.info("No current node set, yet (possibly first node connected)")

          {values, current_node} =
            if Sec_Nodes.node_exists?(state[:uuid]) do
              current_node = Sec_Nodes.get_sec_node_by_uuid(state[:uuid])
              values = Model.get_val_map(current_node)

              Phoenix.PubSub.subscribe(
                :secop_client_pubsub,
                SEC_Node.get_values_pubsub_topic(current_node)
              )
              Phoenix.PubSub.subscribe(
                :secop_client_pubsub,
                SEC_Node.get_error_pubsub_topic(current_node)
              )

              Logger.info("Current node updated")
              {values, current_node}
            else
              Logger.warning(
                "Node with UUID #{state[:uuid]} does not exist in the database, retrying..."
              )

              Process.send_after(self(), {:description_change, pubsub_topic, state}, 500)
              {values, current_node}
            end

          assign(socket, current_node: current_node) |> assign(values: values)

        state.node_id == SEC_Node.get_node_id(current_node) ->
          {values, current_node} =
            if Sec_Nodes.node_exists?(state[:uuid]) do
              # unsubscribe from all subs (prevents double updates)
              Phoenix.PubSub.unsubscribe(
                :secop_client_pubsub,
                SEC_Node.get_values_pubsub_topic(current_node)
              )
              Phoenix.PubSub.unsubscribe(
                :secop_client_pubsub,
                SEC_Node.get_error_pubsub_topic(current_node)
              )


              current_node = Sec_Nodes.get_sec_node_by_uuid(state[:uuid])
              values = Model.get_val_map(current_node)

              Phoenix.PubSub.subscribe(
                :secop_client_pubsub,
                SEC_Node.get_values_pubsub_topic(current_node)
              )
              Phoenix.PubSub.subscribe(
                :secop_client_pubsub,
                SEC_Node.get_error_pubsub_topic(current_node)
              )

              Logger.info("Current node updated")
              {values, current_node}
            else
              Phoenix.PubSub.unsubscribe(
                :secop_client_pubsub,
                SEC_Node.get_values_pubsub_topic(current_node)
              )
              Phoenix.PubSub.unsubscribe(
                :secop_client_pubsub,
                SEC_Node.get_error_pubsub_topic(current_node)
              )

              Logger.warning(
                "Node with UUID #{state[:uuid]} does not exist in the database, unsubscribed from pubsub topic."
              )

              Process.send_after(self(), {:description_change, pubsub_topic, state}, 500)
              {values, current_node}
            end

          assign(socket, current_node: current_node) |> assign(values: values)

        true ->
          Logger.info("Current node not updated")
          socket
      end

    {:noreply, assign(socket, active_nodes: active_nodes)}
  end

  def handle_info({:conn_state, pubsub_topic, active}, socket) do
    Logger.info("Connection state change for '#{pubsub_topic}',to: Active == #{active}")

    active_nodes = socket.assigns.active_nodes

    updated_node =
      socket.assigns.active_nodes[pubsubtopic_to_node_id(pubsub_topic)]
      |> Map.put(:active, active)

    new_active_nodes = Map.put(active_nodes, pubsubtopic_to_node_id(pubsub_topic), updated_node)

    socket =
      socket
      |> assign(
        :active_nodes,
        new_active_nodes
      )

    {:noreply, socket}
  end

  def handle_info({:state_change, pubsub_topic, state}, socket) do
    Logger.info("node state change: #{pubsub_topic} #{state.state}")

    node_id = pubsubtopic_to_node_id(pubsub_topic)
    active_nodes = socket.assigns.active_nodes |> Map.put(node_id, state)

    {:noreply, assign(socket, active_nodes: active_nodes)}
  end

  def handle_info({:new_node, pubsub_topic, :connection_failed}, socket) do
    Logger.info("connection to: #{pubsub_topic} could not be established")
    send(self(), {:put_flash, [:error, "Connection to node '#{pubsub_topic}' failed."]})

    {:noreply,socket}
  end


  def handle_info({:new_node, pubsub_topic, state}, socket) do
    Logger.info("new node discovered: #{pubsub_topic} #{inspect(state)}")

    active_nodes =
      socket.assigns.active_nodes |> Map.put(pubsubtopic_to_node_id(pubsub_topic), state)

    socket = if socket.assigns.show_connect_modal do
      socket |> assign(show_connect_modal: false)
    else
      send(self(), {:put_flash, [:info, "New node '#{pubsub_topic}' discovered."]})
      socket
    end

    {:noreply, assign(socket, active_nodes: active_nodes)}
  end

  @impl true
  def handle_info({:put_flash, [type, message]}, socket) do
    Process.send_after(self(), :clear_flash, 5000)
    {:noreply, put_flash(socket, type, message)}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}

  end

  @impl true
  def handle_info({:value_update, module, accessible, data_report}, socket) do
    send_update(SecopServiceWeb.Components.HistoryDB,
      id: "module-plot:#{module}",
      value_update: data_report,
      parameter: accessible
    )

    socket =
      case Model.value_update(socket.assigns.values, module, accessible, data_report) do
        {:ok, :equal, _values} ->
          socket

        {:ok, :updated, values} ->
          node_id_str =
            "#{to_string(socket.assigns.current_node.host)}:#{socket.assigns.current_node.port}"

          update_components(
            node_id_str,
            module,
            accessible,
            data_report
          )

          assign(socket, :values, values)

        {:error, :parameter_not_found, _values} ->
          Logger.warning("Parameter #{accessible} in module #{module} not found in values")
          socket
      end

    {:noreply, socket}
  end

    @impl true
  def handle_info({:error_update, module, accessible, error_report}, socket) do
    error_report = {:error_report, error_report}

    socket =
      case Model.value_update(socket.assigns.values, module, accessible, error_report) do
        {:ok, :equal, _values} ->
          socket

        {:ok, :updated, values} ->
          node_id_str =
            "#{to_string(socket.assigns.current_node.host)}:#{socket.assigns.current_node.port}"

          update_components(
            node_id_str,
            module,
            accessible,
            error_report
          )

          assign(socket, :values, values)

        {:error, :parameter_not_found, _values} ->
          Logger.warning("Parameter #{accessible} in module #{module} not found in values")
          socket
      end

    {:noreply, socket}
  end


  def handle_event("toggle-conn-state", _unsigned_params, socket) do
    Logger.info("Toggling connection state for current node")

    node_state = socket.assigns.active_nodes[SEC_Node.get_node_id(socket.assigns.current_node)]
    node_id = node_state.node_id
    active = node_state.active

    Task.start(fn ->
      case active do
        true ->
          SEC_Node_Statem.deactivate(node_id)

        false ->
          SEC_Node_Statem.activate(node_id)
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("node-select", %{"pstopic" => new_pubsub_topic}, socket) do
    # unsubscribe from the current node's pubsub topic
    Logger.info("Switching to node with pubsub topic: #{new_pubsub_topic}")

    current_node = socket.assigns.current_node

    Phoenix.PubSub.unsubscribe(
      :secop_client_pubsub,
      SEC_Node.get_values_pubsub_topic(current_node)
    )

    Phoenix.PubSub.unsubscribe(
      :secop_client_pubsub,
      SEC_Node.get_error_pubsub_topic(current_node)
    )

    # subscribe to the new node's pubsub topic & update the model
    new_node_id = pubsubtopic_to_node_id(new_pubsub_topic)
    new_model = model_from_socket(socket) |> Model.set_current_node(new_node_id)
    socket = model_to_socket(new_model, socket)

    Phoenix.PubSub.subscribe(
      :secop_client_pubsub,
      SEC_Node.get_values_pubsub_topic(new_model.current_node)
    )

    Phoenix.PubSub.subscribe(
      :secop_client_pubsub,
      SEC_Node.get_error_pubsub_topic(new_model.current_node)
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_parameter", unsigned_params, socket) do
    send_update(SecopServiceWeb.Components.ParameterValueDisplay,
      id: "#{unsigned_params["location"]}:" <> path_from_unsigned_params(unsigned_params),
      control: :set_parameter,
      unsigned_params: unsigned_params
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_parameter", unsigned_params, socket) do
    send_update(SecopServiceWeb.Components.ParameterValueDisplay,
      id: "#{unsigned_params["location"]}:" <> path_from_unsigned_params(unsigned_params),
      control: :validate,
      unsigned_params: unsigned_params
    )

    {:noreply, socket}
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

  def handle_event("trigger-node-scan", _params, socket) do
    Logger.info("Triggering node scan...")
    NodeDiscover.scan()
    {:noreply, socket}
  end

  def handle_event("connect-node", params, socket) do
    opts = %{
      host: params["host"] |> String.to_charlist(),
      port: params["port"] |> String.to_integer(),
      manual: true,
      reconnect_backoff: 5000
    }

    SEC_Node_Supervisor.start_child(opts)
    {:noreply, socket}
  end

  defp pubsubtopic_to_node_id(pubsub_topic) do
    [ip, port] = String.split(pubsub_topic, ":")
    {String.to_charlist(ip), String.to_integer(port)}
  end

  def update_components(node_id_str, module, "status", data_report) do
    send_update(SecopServiceWeb.Components.ModuleIndicator,
      id: "module_indicator:" <> node_id_str <> ":" <> module,
      value_update: data_report
    )

    send_update(SecopServiceWeb.Components.ModuleIndicator,
      id: "module_indicator_mod:" <> node_id_str <> ":" <> module,
      value_update: data_report
    )

    send_update(SecopServiceWeb.Components.ParameterValueDisplay,
      id: "parameter_value:" <> node_id_str <> ":" <> module <> ":" <> "status",
      value_update: data_report
    )
  end

  def update_components(node_id_str, module, "value", data_report) do
    send_update(SecopServiceWeb.Components.ParameterValueDisplay,
      id: "module_dash:" <> node_id_str <> ":" <> module <> ":" <> "value",
      value_update: data_report
    )

    send_update(SecopServiceWeb.Components.ParameterValueDisplay,
      id: "parameter_value:" <> node_id_str <> ":" <> module <> ":" <> "value",
      value_update: data_report
    )
  end

  def update_components(node_id_str, module, "target", data_report) do
    send_update(SecopServiceWeb.Components.ParameterValueDisplay,
      id: "parameter_value:" <> node_id_str <> ":" <> module <> ":" <> "target",
      value_update: data_report
    )

    send_update(SecopServiceWeb.Components.ParameterValueDisplay,
      id: "module_dash:" <> node_id_str <> ":" <> module <> ":" <> "target",
      value_update: data_report
    )
  end

  def update_components(node_id_str, module, accessible, data_report) do
    send_update(SecopServiceWeb.Components.ParameterValueDisplay,
      id: "parameter_value:" <> node_id_str <> ":" <> module <> ":" <> accessible,
      value_update: data_report
    )
  end

  # defp remove_last_segment(topic) do
  #  parts = String.split(topic, ":")
  #  parts |> Enum.drop(-1) |> Enum.join(":")
  # end

  defp path_from_unsigned_params(unsigned_params) do
    host = unsigned_params["host"]
    port = unsigned_params["port"]
    module = unsigned_params["module"]
    parameter = unsigned_params["parameter"]

    "#{host}:#{port}:#{module}:#{parameter}"
  end
end
