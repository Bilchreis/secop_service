defmodule SecopServiceWeb.Components.ParameterValueDisplay do
  use Phoenix.LiveComponent

  require Logger

  alias SecopServiceWeb.DashboardLive.Model
  alias SecopService.Sec_Nodes.ParameterValue
  alias SecopService.NodeControl
  alias NodeTable
  import SecopServiceWeb.CoreComponents

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
          "Data report for module #{module_name} and parameter #{parameter.name} not found in NodeTable for node #{inspect(node_id)}}."
        )

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
        {name, _} =
          parameter.datainfo["members"]
          |> Enum.find(fn
            {_name, val} -> val == raw_value
            _ -> false
          end)

        "#{raw_value}: #{name}"

      _ ->
        if unit == "" do
          "#{Jason.encode!(raw_value, pretty: true)}"
        else
          "#{Jason.encode!(raw_value, pretty: true)} #{unit}"
        end
    end
  end

  @impl true
  def update(
        %{
          class: class,
          host: host,
          port: port,
          module_name: module_name,
          parameter: parameter,
          location: location
        } = _assigns,
        socket
      ) do
    node_id = {String.to_charlist(host), port}

    parameter_value =
      case get_parameter_value(module_name, node_id, parameter) do
        nil -> "Waiting for data..."
        val_map -> Map.get(val_map, :data_report) |> Enum.at(0) |> get_display_value(parameter)
      end

    set_form =
      to_form(%{
        "location" => "#{location}",
        "host" => to_string(host),
        "port" => Integer.to_string(port),
        "parameter" => parameter.name,
        "module" => module_name,
        "value" => nil
      })

    socket =
      socket
      |> assign(:parameter, parameter)
      |> assign(:module_name, module_name)
      |> assign(:node_id, node_id)
      |> assign(:host, host)
      |> assign(:port, port)
      |> assign(:class, class)
      |> assign(:set_form, set_form)
      |> assign(:location, location)
      |> assign_new(:parameter_value, fn -> parameter_value end)

    {:ok, socket}
  end

  @impl true
  def update(%{value_update: data_report} = _assigns, socket) do
    parameter = socket.assigns.parameter

    parameter_value =
      case data_report do
        nil -> "Waiting for data..."
        val_map -> Enum.at(data_report, 0) |> get_display_value(parameter)
      end

    {:ok, assign(socket, :parameter_value, parameter_value)}
  end

  def update(%{control: :validate, unsigned_params: unsigned_params} = _assigns, socket) do
    Logger.info(
      "Validating parameter #{unsigned_params["parameter"]} with value #{unsigned_params["value"]}"
    )

    updated_set_form =
      NodeControl.validate(
        unsigned_params,
        socket.assigns.parameter.datainfo,
        socket.assigns.set_form
      )

    {:ok, assign(socket, :set_form, updated_set_form)}
  end

  def update(%{control: :set_parameter, unsigned_params: unsigned_params} = _assigns, socket) do
    Logger.info(
      "Setting parameter #{unsigned_params["parameter"]} to #{unsigned_params["value"]}"
    )

    ret = NodeControl.change(unsigned_params)
    Logger.info("NodeControl.change returned: #{inspect(ret)}")

    updated_set_form =
      NodeControl.validate(
        unsigned_params,
        socket.assigns.parameter.datainfo,
        socket.assigns.set_form
      )

    {:ok, assign(socket, :set_form, updated_set_form)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex gap-2 mt-2 ">
      <div class={[
        "flex-1 max-h-80 bg-zinc-300 dark:bg-zinc-800 border rounded-lg p-2 border-stone-500 overflow-scroll",
        @class
      ]}>
        <span class="font-mono text-gray-900 dark:text-gray-200 opacity-100">
          <pre>{@parameter_value}</pre>
        </span>
      </div>
      <%= if not @parameter.readonly do %>
        <div class="flex justify-between items-start">
          <.form
            for={@set_form}
            phx-submit="set_parameter"
            phx-change="validate_parameter"
            class="flex space-x-2"
          >
            <input type="hidden" name="port" value={Phoenix.HTML.Form.input_value(@set_form, :port)} />
            <input type="hidden" name="host" value={Phoenix.HTML.Form.input_value(@set_form, :host)} />
            <input
              type="hidden"
              name="location"
              value={Phoenix.HTML.Form.input_value(@set_form, :location)}
            />
            <input
              type="hidden"
              name="module"
              value={Phoenix.HTML.Form.input_value(@set_form, :module)}
            />
            <input type="hidden" name="parameter" value={@parameter.name} />
            <.input
              name="value"
              type="text"
              field={@set_form[:value]}
              placeholder="new value"
              phx-debounce="500"
              id={"form:" <> to_string(@parameter.id) <> @location}
              class="flex-1 max-h-80 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2 border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
            />
            <button
              type="submit"
              class="font-semibold pr-4 pl-4 bg-zinc-300 dark:bg-zinc-800 rounded-lg p-1 border border-stone-500 hover:bg-zinc-700 dark:hover:bg-zinc-700 opacity-100"
            >
              Set
            </button>
          </.form>
        </div>
      <% end %>
    </div>
    """
  end
end
