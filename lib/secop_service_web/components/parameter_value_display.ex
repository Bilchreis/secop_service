defmodule SecopServiceWeb.Components.ParameterValueDisplay do
  use Phoenix.LiveComponent

  require Logger

  alias SecopServiceWeb.DashboardLive.Model
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

  def get_display_value(raw_value, datainfo, _depth) do
    unit = datainfo["unit"] || ""

    case datainfo["type"] do
      "double" ->
        formatted =
          case raw_value do
            val when val == 0.0 ->
              "0.0"

            val when abs(val) >= 1000 or abs(val) < 0.001 ->
              # Use scientific notation for very large or very small numbers
              :io_lib.format("~.3e", [val]) |> to_string()

            val ->
              # Use regular decimal notation with up to 6 decimal places, removing trailing zeros
              :io_lib.format("~.6f", [val])
              |> to_string()
              |> String.replace(~r/\.?0+$/, "")
          end

        "#{formatted} #{unit}" |> String.trim()

      "scaled" ->
        formatted =
          case raw_value do
            val when val == 0.0 ->
              "0"

            val when abs(val) >= 1000 or abs(val) < 0.001 ->
              :io_lib.format("~.3e", [val]) |> to_string()

            val ->
              :io_lib.format("~.6f", [val])
              |> to_string()
              |> String.replace(~r/\.?0+$/, "")
          end

        "#{formatted} #{unit}" |> String.trim()

      "enum" ->
        # Return the name for display
        {name, _} =
          datainfo["members"]
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
        val_map -> Map.get(val_map, :data_report) |> Enum.at(0)
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
    # parameter = socket.assigns.parameter

    parameter_value =
      case data_report do
        nil -> "Waiting for data..."
        [value, _qualifiers] -> value
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

  attr :parameter_value, :any, required: true
  attr :datainfo, :map, required: true
  attr :depth, :integer, default: 0

  def display_parameter(assigns) do
    ~H"""
    <%= case @datainfo["type"] do %>
      <% "struct" -> %>
        <.display_struct parameter_value={@parameter_value} datainfo={@datainfo} />
      <% "tuple" -> %>
        <.display_tuple parameter_value={@parameter_value} datainfo={@datainfo} />
      <% type when type in ["double", "int", "scaled"] -> %>
        <.display_numeric parameter_value={@parameter_value} datainfo={@datainfo} />
      <% "bool" -> %>
        <.display_bool parameter_value={@parameter_value} datainfo={@datainfo} />
      <% "enum" -> %>
        <.display_enum parameter_value={@parameter_value} datainfo={@datainfo} />
      <% "array" -> %>
        <.display_array parameter_value={@parameter_value} datainfo={@datainfo} />
      <% "string" -> %>
        <.display_string parameter_value={@parameter_value} datainfo={@datainfo} />
      <% "blob" -> %>
        blob
      <% "matrix" -> %>
        matrix
      <% _ -> %>
        unknown type
    <% end %>
    """
  end

  attr :datainfo, :map, required: true
  attr :parameter_value, :any, required: true

  def display_numeric(assigns) do
    assigns =
      assigns
      |> assign(:str_value, get_display_value(assigns.parameter_value, assigns.datainfo, 0))

    ~H"""
    {@str_value}
    """
  end

  attr :datainfo, :map, required: true
  attr :parameter_value, :any, required: true

  def display_string(assigns) do
    assigns =
      assigns
      |> assign(:str_value, get_display_value(assigns.parameter_value, assigns.datainfo, 0))

    ~H"""
    {@str_value}
    """
  end

  attr :datainfo, :map, required: true
  attr :parameter_value, :boolean, required: true

  def display_bool(assigns) do
    badge_color =
      case assigns.parameter_value do
        true -> "bg-green-100 text-green-800 dark:bg-green-700 dark:text-green-200"
        false -> "bg-red-100 text-red-800 dark:bg-red-700 dark:text-red-200"
        _ -> "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
      end

    assigns =
      assigns
      |> assign(:str_value, get_display_value(assigns.parameter_value, assigns.datainfo, 0))
      |> assign(:badge_color, badge_color)

    ~H"""
    <div class={"w-fit  px-3 py-1.5 rounded-md border #{@badge_color}"}>
      <span>{"#{@parameter_value}"}</span>
    </div>
    """
  end

  attr :datainfo, :map, required: true
  attr :parameter_value, :integer, required: true

  def display_enum(assigns) do
    # Color lookup table with 20 different color combinations - muted dark mode colors
    color_lut = [
      "bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-300 border-red-300 dark:border-red-800",
      "bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300 border-green-300 dark:border-green-800",
      "bg-blue-100 text-blue-800 dark:bg-blue-900/50 dark:text-blue-300 border-blue-300 dark:border-blue-800",
      "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/50 dark:text-yellow-300 border-yellow-300 dark:border-yellow-800",
      "bg-purple-100 text-purple-800 dark:bg-purple-900/50 dark:text-purple-300 border-purple-300 dark:border-purple-800",
      "bg-pink-100 text-pink-800 dark:bg-pink-900/50 dark:text-pink-300 border-pink-300 dark:border-pink-800",
      "bg-indigo-100 text-indigo-800 dark:bg-indigo-900/50 dark:text-indigo-300 border-indigo-300 dark:border-indigo-800",
      "bg-orange-100 text-orange-800 dark:bg-orange-900/50 dark:text-orange-300 border-orange-300 dark:border-orange-800",
      "bg-teal-100 text-teal-800 dark:bg-teal-900/50 dark:text-teal-300 border-teal-300 dark:border-teal-800",
      "bg-cyan-100 text-cyan-800 dark:bg-cyan-900/50 dark:text-cyan-300 border-cyan-300 dark:border-cyan-800",
      "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/50 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800",
      "bg-lime-100 text-lime-800 dark:bg-lime-900/50 dark:text-lime-300 border-lime-300 dark:border-lime-800",
      "bg-amber-100 text-amber-800 dark:bg-amber-900/50 dark:text-amber-300 border-amber-300 dark:border-amber-800",
      "bg-rose-100 text-rose-800 dark:bg-rose-900/50 dark:text-rose-300 border-rose-300 dark:border-rose-800",
      "bg-violet-100 text-violet-800 dark:bg-violet-900/50 dark:text-violet-300 border-violet-300 dark:border-violet-800",
      "bg-fuchsia-100 text-fuchsia-800 dark:bg-fuchsia-900/50 dark:text-fuchsia-300 border-fuchsia-300 dark:border-fuchsia-800",
      "bg-sky-100 text-sky-800 dark:bg-sky-900/50 dark:text-sky-300 border-sky-300 dark:border-sky-800",
      "bg-slate-100 text-slate-800 dark:bg-slate-800/50 dark:text-slate-300 border-slate-300 dark:border-slate-700",
      "bg-zinc-100 text-zinc-800 dark:bg-zinc-800/50 dark:text-zinc-300 border-zinc-300 dark:border-zinc-700",
      "bg-stone-100 text-stone-800 dark:bg-stone-800/50 dark:text-stone-300 border-stone-300 dark:border-stone-700"
    ]

    # Return the name for display
    {name, _} =
      assigns.datainfo["members"]
      |> Enum.find(fn
        {_name, val} -> val == assigns.parameter_value
        _ -> false
      end)

    # Get color based on parameter value using modulo to cycle through colors
    color_index = rem(assigns.parameter_value, length(color_lut))
    color_classes = Enum.at(color_lut, color_index)

    assigns =
      assigns
      |> assign(:member_name, name)
      |> assign(:color_classes, color_classes)

    ~H"""
    <div class={"w-fit flex items-center px-3 py-1.5 rounded-md border #{@color_classes}"}>
      <span class="font-mono text-sm font-medium">{@member_name}</span>
      <span class="ml-2 px-2 py-0.5 rounded-full bg-white/75 dark:bg-gray-800/75 text-xs font-mono">
        {@parameter_value}
      </span>
    </div>
    """
  end

  attr :datainfo, :map, required: true
  attr :parameter_value, :map, required: true

  def display_struct(assigns) do
    ~H"""
    <div class="grid grid-cols-[auto_1fr] gap-x-2 gap-y-2 items-center">
      <%= for {member_name, member_info} <- @datainfo["members"] do %>
        <div class="font-semibold text-gray-700 dark:text-gray-300 text-right">
          {member_name}:
        </div>
        <div>
          <.display_parameter
            parameter_value={Map.get(@parameter_value, String.to_existing_atom(member_name))}
            datainfo={member_info}
          />
        </div>
      <% end %>
    </div>
    """
  end

  attr :datainfo, :map, required: true
  attr :parameter_value, :map, required: true

  def display_tuple(assigns) do
    ~H"""
    <div class="flex items-center">
      (
      <%= for element <- Enum.intersperse(Enum.with_index(@datainfo["members"]), :comma) do %>
        <%= if element == :comma do %>
          <span>,</span>
        <% else %>
          <div>
            <.display_parameter
              parameter_value={Enum.at(@parameter_value, elem(element, 1))}
              datainfo={elem(element, 0)}
            />
          </div>
        <% end %>
      <% end %>
      )
    </div>
    """
  end

  attr :datainfo, :map, required: true
  attr :parameter_value, :map, required: true

  def display_array(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center">
      [
      <%= for element <- Enum.intersperse(@parameter_value, :comma) do %>
        <%= if element == :comma do %>
          <span>,</span>
        <% else %>
          <div>
            <.display_parameter parameter_value={element} datainfo={@datainfo["members"]} />
          </div>
        <% end %>
      <% end %>
      ]
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex gap-2 mt-2 ">
      <div class={[
        "flex-1 max-h-80 bg-zinc-300 dark:bg-zinc-800 border rounded-lg p-2 border-stone-500 overflow-scroll",
        @class
      ]}>
        <div class="font-mono text-gray-900 dark:text-gray-200 opacity-100">
          <.display_parameter parameter_value={@parameter_value} datainfo={@parameter.datainfo} />
        </div>
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
