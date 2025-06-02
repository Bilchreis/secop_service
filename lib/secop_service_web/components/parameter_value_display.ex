defmodule SecopServiceWeb.Components.ParameterValueDisplay do
  use Phoenix.LiveComponent

  require Logger

  alias SecopServiceWeb.DashboardLive.Model
  alias SecopService.Sec_Nodes.ParameterValue
  alias NodeTable




  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  defp get_parameter_value(module_name, node_id, parameter) do

    case NodeTable.lookup(
          node_id,
          {:data_report, String.to_existing_atom(module_name),
          String.to_existing_atom(parameter.name)}
        ) do
      {:ok, data_report} ->
        Model.process_data_report(parameter.name, data_report, parameter.datainfo)


      {:error, :notfound} ->
        Logger.warning(
          "Data report for module #{module_name} and parameter #{parameter.name} not found in NodeTable for node #{inspect(node_id)}}.")
        Model.process_data_report(parameter.name, nil, parameter.datainfo)

    end
  end


  def get_display_value(raw_value, parameter) do
    unit = parameter.datainfo["unit"] || ""

    case parameter.datainfo["type"] do
      "double" ->
        format_string = parameter.datainfo["fmtstr"] || "%.6g"
        # Simple formatting with :io_lib.format
        formatted = ExPrintf.sprintf(format_string, [raw_value])
        "#{formatted} #{unit}"

      "scaled" ->
        format_string = parameter.datainfo["fmtstr"] || "%.6g"
        formatted = ExPrintf.sprintf(format_string, [raw_value])
        "#{formatted} #{unit}"

      "enum" ->
        # Return the name for display
         {name, _} = parameter.datainfo["members"]
        |> Enum.find(fn
          {_name, val} -> val == raw_value
          _ -> false
        end)

        name

      _ ->
        if unit == "" do
          "#{Jason.encode!(raw_value)}"
        else
          "#{Jason.encode!(raw_value)} #{unit}"
        end
    end
  end

  @impl true
  def update(%{
    host: host,
    port: port,
    module_name: module_name,
    parameter: parameter} = _assigns, socket) do

    node_id = {String.to_charlist(host), port}

    parameter_value = case get_parameter_value(module_name, node_id, parameter) do
      nil -> "Waiting for data..."
      val_map   -> Map.get(val_map,:data_report) |> Enum.at(0) |>  get_display_value(parameter)
    end


    socket =
      socket
      |> assign(:parameter, parameter)
      |> assign(:module_name, module_name)
      |> assign(:node_id, node_id)
      |> assign_new(:parameter_value, fn -> parameter_value end )

    {:ok, socket}
  end

  @impl true
  def update(%{value_update: data_report} = _assigns, socket) do
    parameter = socket.assigns.parameter




    parameter_value = case data_report do
      nil -> "Waiting for data..."
      val_map   -> Enum.at(data_report,0) |>  get_display_value(parameter)
    end

    {:ok, assign(socket, :parameter_value, parameter_value)}
  end







  @impl true
  def render(assigns) do
    ~H"""
    <div class = "bg-gray-600 border rounded-lg p-2 mt-2 border-stone-400">
      <span class= "text-white opacity-100">{@parameter_value}</span>
    </div>
    """
  end
end
