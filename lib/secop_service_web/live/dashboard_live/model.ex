defmodule SecopServiceWeb.DashboardLive.Model do
  require Logger
  alias SecopService.Sec_Nodes.SEC_Node
  alias SEC_Node_Supervisor
  use Phoenix.Component
  alias SecopService.Sec_Nodes
  alias NodeTable

  def get_initial_model() do
    active_nodes = SEC_Node_Supervisor.get_active_nodes()

    # Select only the relevant keys from each node
    active_nodes =
      Enum.reduce(active_nodes, %{}, fn {node_id, node}, acc ->
        node =
          Map.take(node, [
            :host,
            :port,
            :node_id,
            :equipment_id,
            :pubsub_topic,
            :state,
            :active,
            :uuid,
            :error
          ])

        Map.put(acc, node_id, node)
      end)

    model =
      if active_nodes == %{} do
        %{active_nodes: %{}, current_node: nil, values: nil}
      else
        # Get an arbitrary entry from the active_nodes map
        {_current_node_key, current_node} = Map.to_list(active_nodes) |> List.first()

        current_node =
          if Sec_Nodes.node_exists?(current_node[:uuid]) do
            Sec_Nodes.get_sec_node_by_uuid(current_node[:uuid])
          end

        %{
          active_nodes: active_nodes,
          current_node: current_node,
          values: get_val_map(current_node)
        }
      end

    model
  end

  def get_val_map(db_node) do
    node_id = SEC_Node.get_node_id(db_node)

    Enum.reduce(db_node.modules, %{}, fn module, mod_acc ->
      parameter_map =
        Enum.reduce(module.parameters, %{}, fn parameter, param_acc ->
          param_val =
            case NodeTable.lookup(
                   node_id,
                   {:data_report, String.to_existing_atom(module.name),
                    String.to_existing_atom(parameter.name)}
                 ) do
              {:ok, data_report} ->
                data_report

              {:error, :notfound} ->
                Logger.warning(
                  "Data report for module #{module.name} and parameter #{parameter.name} not found in NodeTable for node #{db_node.host}:#{db_node.port}."
                )

                nil
            end

          param_val =
            process_data_report(parameter.name, param_val, parameter.datainfo)
            |> Map.put(:datainfo, parameter.datainfo)

          Map.put(param_acc, parameter.name, param_val)
        end)

      Map.put(mod_acc, module.name, parameter_map)
    end)
  end

  def set_current_node(model, node_id) do
    current_node = Map.get(model.active_nodes, node_id)

    # Get the current node from the active nodes map
    model =
      if Sec_Nodes.node_exists?(current_node[:uuid]) do
        db_node = Sec_Nodes.get_sec_node_by_uuid(current_node[:uuid])

        model =
          model
          |> Map.put(:current_node, db_node)
          |> Map.put(:values, get_val_map(db_node))

        model
      else
        Logger.warning("Node with UUID #{current_node[:uuid]} does not exist in the database.")
        model
      end

    model
  end

  def process_data_report("status", data_report, datainfo) do
    if data_report != nil do
      [value, _qualifiers] = data_report

      [stat_code, stat_string] = value

      %{
        data_report: data_report,
        stat_string: stat_string,
        stat_code: stat_code_lookup(stat_code, datainfo),
        stat_color: stat_code_to_color(stat_code),
        datainfo: datainfo
      }
    else
      %{
        data_report: nil,
        datainfo: datainfo
      }
    end
  end

  def process_data_report(nil, nil, nil) do
    nil
  end

  def process_data_report(_accessible, data_report, datainfo) do
    %{data_report: data_report, datainfo: datainfo}
  end

  def value_update(values, module, accessible, data_report) do
    # Check if the module exists
    case get_in(values, [module, accessible]) do
      nil ->
        {:error, :parameter_not_found, values}

      old_param_val ->
        new_param_val = process_data_report(accessible, data_report, old_param_val.datainfo)

        if Enum.at(old_param_val.data_report, 0) == Enum.at(new_param_val.data_report, 0) do
          {:ok, :equal, values}
        else
          # Merge the old parameter value with the new one
          merged_param_val = Map.merge(old_param_val, new_param_val)
          {:ok, :updated, put_in(values, [module, accessible], merged_param_val)}
        end
    end
  end

  def stat_code_lookup(stat_code, status_datainfo) do
    status_datainfo["members"]
    |> Enum.find(fn member -> member["type"] == "enum" end)
    |> case do
      %{"members" => members} ->
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

  def stat_code_to_color(stat_code) do
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
end
