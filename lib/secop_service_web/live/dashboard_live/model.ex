defmodule SecopServiceWeb.DashboardLive.Model do
  alias SecopServiceWeb.DashboardLive.Plot
  alias SEC_Node_Supervisor
  use Phoenix.Component
  alias SecopService.Sec_Nodes

  def get_initial_model() do
    active_nodes = SEC_Node_Supervisor.get_active_nodes()

    model =
      cond do
        active_nodes == %{} ->
          %{active_nodes: %{}, current_node_key: nil, current_module_key: nil}

        true ->
          # Get an arbitrary entry from the active_nodes map
          {current_node_key, _current_node_value} = Map.to_list(active_nodes) |> List.first()

          initial_active_nodes =
            Enum.reduce(active_nodes, %{}, fn {node_id, node}, acc ->
              {current_module_key, _current_module_value} =
                node[:description][:modules] |> Map.to_list() |> List.first()

              node = Map.put(node, :current_module_key, current_module_key)
              Map.put(acc, node_id, init_node(node))
            end)



          %{
            active_nodes: initial_active_nodes,
            current_node_key: current_node_key,
            current_module_key: initial_active_nodes[current_node_key][:current_module_key]
          }
      end

    model
  end

  def set_new_current_node(model, new_node_id) do
    model = %{model | current_node_key: new_node_id}

    model =
      Map.put(
        model,
        :current_module_key,
        model.active_nodes[model.current_node_key][:current_module_key]
      )

    model
  end

  def get_current_node(model) do
    current_node =
      case model.current_node_key do
        nil -> nil
        current_node_key -> model.active_nodes[current_node_key]
      end

    current_node
  end

  def set_state(model, state) do
    active_nodes = model.active_nodes

    model =
      case state.state do
        :initialized ->
          state = init_node(state)
          active_nodes = Map.put(active_nodes, state.node_id, state)

          model =
            case get_current_node(model) do
              nil -> set_new_current_node(model, state.node_id)
              _ -> model
            end

          current_node = get_current_node(model)
          ## This prevents double subscription to the same topic
          Phoenix.PubSub.unsubscribe(:secop_client_pubsub, current_node.pubsub_topic)
          Phoenix.PubSub.subscribe(:secop_client_pubsub, current_node.pubsub_topic)
          Map.put(model, :active_nodes, active_nodes)

        _ ->
          model
      end

    model =
      cond do
        Map.has_key?(model.active_nodes, state.node_id) ->
          put_in(model, [:active_nodes, state.node_id, :state], state.state)

        true ->
          model
      end

    model
  end

  def update_model_values(model, values_map) do
    curr_node_key = model.current_node_key
    current_node = model[:active_nodes][curr_node_key]

    updated_node = update_node_values(current_node, values_map)

    updated_model = put_in(model, [:active_nodes, curr_node_key], updated_node)

    updated_model
  end

  def init_node(node) do
    modules =
      Enum.reduce(node[:description][:modules], %{}, fn {module_name, module_description}, acc ->
        parameters =
          Enum.reduce(module_description[:parameters], %{}, fn {parameter_name,
                                                                parameter_description},
                                                               param_acc ->
            new_param_description =
              Map.put(parameter_description, :value, nil)
              |> Map.put(:plot_data, {[], []})

            new_param_description =
              update_param_descr(nil, parameter_name, new_param_description)
              |> Map.put(
                :chart_id,
                "plotly:#{node.host}:#{node.port}:#{module_name}:#{parameter_name}"
              )
              |> Map.put(
                :parameter_id,
                "#{node.host}:#{node.port}:#{module_name}:#{parameter_name}"
              )
              |> Map.put(
                :set_form,
                to_form(%{
                  "host" => to_string(node.host),
                  "port" => Integer.to_string(node.port),
                  "parameter" => parameter_name,
                  "module" => module_name,
                  "value" => nil
                })
              )

            updated_param_acc = Map.put(param_acc, parameter_name, new_param_description)

            updated_param_acc
          end)

        module_description =
          Map.put(
            module_description,
            :chart_id,
            "plotly:#{node.host}:#{node.port}:#{module_name}"
          )
          |> Map.put(:parameters, parameters)

        Map.put(acc, module_name, module_description)
      end)

    updated_node = put_in(node[:description][:modules], modules)

    updated_node
  end

  def update_node_values(node, values_map) do
    modules =
      Enum.reduce(node[:description][:modules], %{}, fn {module_name, module_description}, acc ->
        parameters =
          Enum.reduce(module_description[:parameters], %{}, fn {parameter_name,
                                                                parameter_description},
                                                               param_acc ->
            new_val =
              case values_map do
                nil -> nil
                _ -> Map.get(values_map, module_name) |> Map.get(parameter_name)
              end

            new_param_description =
              update_param_descr(new_val, parameter_name, parameter_description)

            updated_param_acc = Map.put(param_acc, parameter_name, new_param_description)

            updated_param_acc
          end)

        Map.put(acc, module_name, Map.put(module_description, :parameters, parameters))
      end)

    updated_node = put_in(node[:description][:modules], modules)

    updated_node
  end

  def add_node(model, node) do
    node_id = node.node_id

    model =
      cond do
        model.active_nodes == %{} -> model |> Map.put(:current_node_key, node_id)
        true -> model
      end

    active_nodes = model.active_nodes |> Map.put(node_id, node)

    model = model |> Map.put(:active_nodes, active_nodes)

    model
  end

  defp update_param_descr(new_val, parameter_name, parameter_description) do
    new_parameter_description = Map.put(parameter_description, :value, new_val)

    new_keys =
      case parameter_name do
        :status -> parse_status(new_parameter_description)
        _ -> %{}
      end

    Map.merge(new_parameter_description, new_keys)
  end

  defp parse_status(status) do
    statmap =
      case status.value do
        nil ->
          %{stat_code: "stat_code", stat_string: "stat_string", status_color: "bg-gray-500"}

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

      _ ->
        :unknown
    end
  end

  defp stat_code_to_color(stat_code) do
    cond do
      # Disabled
      0 <= stat_code and stat_code < 100 -> "bg-gray-500"
      # IDLE
      100 <= stat_code and stat_code < 200 -> "bg-green-500"
      # WARNING
      200 <= stat_code and stat_code < 300 -> "bg-yellow-500"
      # BUSY
      300 <= stat_code and stat_code < 400 -> "bg-orange-500"
      # ERROR
      400 <= stat_code and stat_code < 500 -> "bg-red-500"
      true -> "bg-white"
    end
  end

  def get_module(model, nodeid, module) do
    get_in(model, [:active_nodes, nodeid, :description, :modules, module])
  end

  def set_module(model, nodeid, module_key, new_module) do
    put_in(model, [:active_nodes, nodeid, :description, :modules, module_key], new_module)
  end

  def get_parameter(model, nodeid, module, parameter) do
    get_in(model, [:active_nodes, nodeid, :description, :modules, module, :parameters, parameter])
  end

  def set_parameter(model, nodeid, module, parameter, new_parameter) do
    put_in(
      model,
      [:active_nodes, nodeid, :description, :modules, module, :parameters, parameter],
      new_parameter
    )
  end

  defp get_plot_tuple(map) do
    chart_id = map.chart_id

    plot = Map.get(map, :plot)

    plotly_data =
      if Map.has_key?(plot, :plotly) do
        Map.get(plot, :plotly)
      else
        nil
      end

    {chart_id, plotly_data}
  end

  def get_module_plot_data(model, nodeid, module) do
    get_module(model, nodeid, module)
    |> get_plot_tuple()
  end

  def get_parameter_plot_data(model, nodeid, module, parameter) do
    get_parameter(model, nodeid, module, parameter)
    |> get_plot_tuple()
  end
end
