defmodule SecopServiceWeb.Components.ParameterValueDisplay do
  use Phoenix.LiveComponent

  require Logger

  alias SecopService.NodeControl
  alias NodeTable
  import SecopServiceWeb.CoreComponents

  import SecopServiceWeb.Components.ParameterFormFieldComponents
  alias SecopService.NodeValues

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  defp get_parameter_value(module_name, node_id, parameter) do
    case NodeTable.lookup(
           {:service, node_id},
           {:data_report, String.to_existing_atom(module_name),
            String.to_existing_atom(parameter.name)}
         ) do
      {:ok, data_report} ->
        data_report

      {:error, :notfound} ->
        Logger.warning(
          "Data report for module #{module_name} and parameter #{parameter.name} not found in NodeTable for node #{inspect(node_id)}."
        )

        NodeValues.process_data_report(parameter.name, nil, parameter.datainfo)

      {:error, :table_not_found} ->
        Logger.info(
          "ETS table not found for node #{inspect(node_id)}, likely during reconnection. Returning nil."
        )

        NodeValues.process_data_report(parameter.name, nil, parameter.datainfo)
    end
  end

  def get_display_value(raw_value, datainfo, _depth) do
    unit = datainfo["unit"] || ""

    case datainfo["type"] do
      "double" ->
        formatted =
          case raw_value do
            nil ->
              "N/A"

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
            nil ->
              "N/A"

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

  def flattened_form_map(
        flattened_map \\ %{},
        path \\ ["value"],
        current_value,
        datainfo,
        depth,
        max_depth
      )

  def flattened_form_map(flattened_map, _path, nil, _datainfo, depth, max_depth)
      when depth < max_depth do
    Map.put(flattened_map, "value", "null")
  end

  def flattened_form_map(flattened_map, path, current_value, datainfo, depth, max_depth)
      when depth < max_depth do
    case datainfo["type"] do
      "struct" ->
        Enum.reduce(datainfo["members"], %{}, fn {member_name, member_info}, acc ->
          if member_info["type"] in ["struct", "tuple"] do
            member_value = Map.get(current_value, String.to_existing_atom(member_name))

            Map.merge(
              acc,
              flattened_form_map(
                %{},
                path ++ [member_name],
                member_value,
                member_info,
                depth + 1,
                max_depth
              )
            )
          else
            member_value = Map.get(current_value, String.to_existing_atom(member_name))
            Map.put(acc, Enum.join(path ++ [member_name], "."), Jason.encode!(member_value))
          end
        end)

      "tuple" ->
        Enum.with_index(datainfo["members"])
        |> Enum.reduce(%{}, fn {member_info, index}, acc ->
          if member_info["type"] in ["struct", "tuple"] do
            member_value = Enum.at(current_value, index)

            Map.merge(
              acc,
              flattened_form_map(
                %{},
                path ++ ["f#{Integer.to_string(index)}"],
                member_value,
                member_info,
                depth + 1,
                max_depth
              )
            )
          else
            member_value = Enum.at(current_value, index)

            Map.put(
              acc,
              Enum.join(path ++ ["f#{Integer.to_string(index)}"], "."),
              Jason.encode!(member_value)
            )
          end
        end)

      _ ->
        Map.put(flattened_map, Enum.join(path, "."), Jason.encode!(current_value))
    end
  end

  def flattened_form_map(flattened_map, path, current_value, _datainfo, depth, max_depth)
      when depth == max_depth do
    Map.put(flattened_map, Enum.join(path, "."), Jason.encode!(current_value))
  end

  @impl true
  def update(
        %{
          class: class,
          host: host,
          port: port,
          module_name: module_name,
          parameter: parameter,
          location: location,
          id_str: id_str
        } = _assigns,
        socket
      ) do
    node_id = {String.to_charlist(host), port}

    val_map = get_parameter_value(module_name, node_id, parameter)

    socket =
      case val_map do
        nil ->
          assign(socket, :parameter_value, nil)
          |> assign(:parameter_error, nil)

        %{data_report: nil} ->
          assign(socket, :parameter_value, nil)
          |> assign(:parameter_error, nil)

        %{error_report: [error_cls, error_msg, _qualifiers]} ->
          assign(socket, :parameter_error, [error_cls, error_msg])
          |> assign(:parameter_value, nil)

        %{data_report: [value, _qualifiers]} ->
          assign(socket, :parameter_value, value)
          |> assign(:parameter_error, nil)

        val_map ->
          Map.get(val_map, :data_report) |> Enum.at(0)
      end

    flat_map =
      flattened_form_map(%{}, ["value"], socket.assigns.parameter_value, parameter.datainfo, 0, 1)

    base_form = %{
      "location" => "#{location}",
      "host" => to_string(host),
      "port" => Integer.to_string(port),
      "parameter" => parameter.name,
      "module" => module_name,
      "value" => Jason.encode!(socket.assigns.parameter_value, pretty: true),
      "form_type" => "simple"
    }

    # Keep set_form with nil value
    set_form =
      case parameter.datainfo["type"] do
        "enum" -> base_form
        _ -> base_form |> Map.put("value", nil)
      end

    set_form = to_form(set_form)

    modal_form =
      base_form
      |> Map.put("form_type", "modal")
      |> Map.merge(flat_map)
      |> to_form()

    socket =
      socket
      |> assign(:parameter, parameter)
      |> assign(:module_name, module_name)
      |> assign(:node_id, node_id)
      |> assign(:host, host)
      |> assign(:port, port)
      |> assign(:class, class)
      |> assign(:set_form, set_form)
      |> assign(:modal_form, modal_form)
      |> assign(:location, location)
      |> assign(:show_parameter_value_modal, false)
      |> assign(:is_composite, parameter.datainfo["type"] in ["struct", "tuple"])
      |> assign(:change_success, nil)
      |> assign(:id_str, id_str)

    {:ok, socket}
  end

  def update(%{action: :clear_highlight} = _assigns, socket) do
    Logger.info("reset change success")
    socket = assign(socket, :change_success, nil)

    {:ok, socket}
  end

  @impl true
  def update(%{value_update: data_report} = _assigns, socket) do
    socket =
      case data_report do
        %{error_report: [error_cls, error_msg, qualifiers]} ->
          Logger.warning("Error Update: #{error_cls}, #{error_msg}, #{inspect(qualifiers)}")
          assign(socket, :parameter_error, [error_cls, error_msg])

        %{data_report: [value, _qualifiers]} ->
          assign(socket, :parameter_value, value)
          |> assign(:parameter_error, nil)

        _ ->
          Logger.warning("Malformed datareport received: #{IO.inspect(data_report)}")
          socket
      end

    {:ok, socket}
  end

  def update(%{control: :validate, unsigned_params: unsigned_params} = _assigns, socket) do
    updated_socket =
      case unsigned_params["form_type"] do
        "simple" ->
          Logger.info(
            "Simple Form: Validating parameter #{unsigned_params["parameter"]} with value #{unsigned_params["value"]}"
          )

          updated_set_form =
            NodeControl.validate(
              unsigned_params,
              socket.assigns.parameter.datainfo,
              socket.assigns.set_form
            )

          assign(socket, :set_form, updated_set_form)

        "modal" ->
          Logger.info(
            "Modal Form: Validating parameter #{unsigned_params["parameter"]} with value #{unsigned_params["value"]}"
          )

          updated_modal_form =
            NodeControl.validate_modal(
              unsigned_params,
              socket.assigns.parameter.datainfo,
              socket.assigns.modal_form
            )

          assign(socket, :modal_form, updated_modal_form)
      end

    {:ok, updated_socket}
  end

  def update(%{control: :set_parameter, unsigned_params: unsigned_params} = _assigns, socket) do
    form =
      case unsigned_params["form_type"] do
        "simple" ->
          socket.assigns.set_form

        "modal" ->
          socket.assigns.modal_form
      end

    validated_form =
      NodeControl.validate(
        unsigned_params,
        socket.assigns.parameter.datainfo,
        form
      )

    if validated_form.errors != [] do
      updated_socket =
        case unsigned_params["form_type"] do
          "simple" ->
            assign(socket, :set_form, validated_form)

          "modal" ->
            assign(socket, :modal_form, validated_form)
        end

      {:ok, updated_socket}
    else
      # removce pretty formatting for sending to NodeControl.change
      not_pretty_value = Jason.decode!(validated_form.params["value"]) |> Jason.encode!()

      unsigned_params = Map.put(unsigned_params, "value", not_pretty_value)

      ret = NodeControl.change(unsigned_params)
      send_update_after(__MODULE__, %{id: socket.assigns.id_str, action: :clear_highlight}, 1000)

      updated_socket =
        case ret do
          {:changed, _module, _parameter, [value, _qualifiers]} ->
            {:ok, str_value} = Jason.encode(value)

            unsigned_params = Map.put(unsigned_params, "value", str_value)

            updated_form =
              NodeControl.validate(
                unsigned_params,
                socket.assigns.parameter.datainfo,
                validated_form
              )

            socket = assign(socket, :change_success, "btn-success")

            case unsigned_params["form_type"] do
              "simple" ->
                assign(socket, :set_form, updated_form)

              "modal" ->
                assign(socket, :modal_form, updated_form)
            end

          {:error, message_type, specifier, error_class, error_message, _} ->
            Logger.error(
              "Error setting parameter #{unsigned_params["parameter"]}: #{message_type}, #{specifier}, #{error_class}, #{error_message}"
            )

            updated_form = %{
              validated_form
              | errors: [value: {"#{error_class}, #{error_message}", []}]
            }

            socket = assign(socket, :change_success, "btn-error")

            case unsigned_params["form_type"] do
              "simple" ->
                assign(socket, :set_form, updated_form)

              "modal" ->
                assign(socket, :modal_form, updated_form)
            end
        end

      Logger.info("change_success: #{updated_socket.assigns.change_success}")

      {:ok, updated_socket}
    end
  end

  attr :parameter_value, :any, required: true
  attr :datainfo, :map, required: true
  attr :depth, :integer, default: 0

  def display_parameter(assigns) do
    ~H"""
    <%= if @parameter_value == nil do %>
      <div class="text-white-500">Waiting for Data...</div>
    <% else %>
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
  def handle_event("close_parameter_value_modal", _params, socket) do
    {:noreply, assign(socket, show_parameter_value_modal: false)}
  end

  @impl true
  def handle_event("open_parameter_value_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_parameter_value_modal: true
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex gap-2 ">
        <div class={[
          "flex-1 max-h-80 bg-base-100 border border-base-content/50 rounded-lg p-2 overflow-scroll mb-2",
          @class
        ]}>
          <div class="font-mono text-base-content opacity-100">
            <.display_parameter parameter_value={@parameter_value} datainfo={@parameter.datainfo} />
          </div>
          <div>
            <%= if @parameter_error != nil do %>
              <div class="text-error mt-2">
                Error: {Enum.at(@parameter_error, 0)} - {Enum.at(@parameter_error, 1)}
              </div>
            <% end %>
          </div>
        </div>
        <%= if not @parameter.readonly  and not @is_composite do %>
          <div class="flex ">
            <.form
              for={@set_form}
              phx-submit="set_parameter"
              phx-change="validate_parameter"
              class="flex space-x-2"
            >
              <input
                type="hidden"
                name="form_type"
                value={Phoenix.HTML.Form.input_value(@set_form, :form_type)}
              />
              <input
                type="hidden"
                name="port"
                value={Phoenix.HTML.Form.input_value(@set_form, :port)}
              />
              <input
                type="hidden"
                name="host"
                value={Phoenix.HTML.Form.input_value(@set_form, :host)}
              />
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
              <%= case @parameter.datainfo["type"] do %>
                <% "enum" -> %>
                  <.input_enum
                    id={"form:" <> to_string(@parameter.id) <> @location}
                    datainfo={@parameter.datainfo}
                    location={@location}
                    modal_form={@set_form}
                    parameter_id={@parameter.id}
                    show_tooltip={false}
                  />
                <% _ -> %>
                  <.input
                    name="value"
                    type="text"
                    field={@set_form[:value]}
                    placeholder="new value"
                    phx-debounce="500"
                    id={"form:" <> to_string(@parameter.id) <> @location}
                    class=" input"
                  />
              <% end %>
              <button
                type="submit"
                class={["btn btn-accent mt-1", @change_success]}
              >
                Set
              </button>
            </.form>
          </div>
        <% end %>
      </div>

      <%= if not @parameter.readonly and @is_composite do %>
        <div class="flex gap-2  ">
          <.form
            for={@set_form}
            phx-submit="set_parameter"
            phx-change="validate_parameter"
            class="flex gap-2"
          >
            <input
              type="hidden"
              name="form_type"
              value={Phoenix.HTML.Form.input_value(@set_form, :form_type)}
            />
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
              class="input"
            />

            <button
              type="submit"
              class="btn btn-accent mt-1"
            >
              Set
            </button>
          </.form>

          <button
            onclick={"modal_" <> to_string(@parameter.id) <> @location <> ".showModal()"}
            phx-click="open_parameter_value_modal"
            phx-target={@myself}
            class="btn mt-1"
          >
            Edit Value
          </button>
        </div>

        <.modal
          id={"modal_" <> to_string(@parameter.id) <> @location}
          title="Change Request Editor"
          show={@show_parameter_value_modal}
        >
          <.form for={@modal_form} phx-submit="set_parameter" phx-change="validate_parameter" class="">
            <input
              type="hidden"
              name="form_type"
              value={Phoenix.HTML.Form.input_value(@modal_form, :form_type)}
            />
            <input
              type="hidden"
              name="port"
              value={Phoenix.HTML.Form.input_value(@modal_form, :port)}
            />
            <input
              type="hidden"
              name="host"
              value={Phoenix.HTML.Form.input_value(@modal_form, :host)}
            />
            <input
              type="hidden"
              name="location"
              value={Phoenix.HTML.Form.input_value(@modal_form, :location)}
            />
            <input
              type="hidden"
              name="module"
              value={Phoenix.HTML.Form.input_value(@modal_form, :module)}
            />

            <.input_parameter
              datainfo={@parameter.datainfo}
              modal_form={@modal_form}
              parameter_id={to_string(@parameter.id)}
              location={@location}
            />

            <input type="hidden" name="parameter" value={@parameter.name} />
            <div class="mt-2">
              JSON Preview:
              <.input
                id={to_string(@parameter.id) <> @location <> "_preview"}
                name="value"
                type="textarea"
                field={@modal_form[:value]}
                placeholder={Phoenix.HTML.Form.input_value(@modal_form, :value)}
                value={Phoenix.HTML.Form.input_value(@modal_form, :value)}
                rows="20"
                class="input flex-1 min-h-80  font-mono "
              />
            </div>
            <button
              type="submit"
              class={["btn btn-accent", @change_success]}
            >
              Set
            </button>
          </.form>
        </.modal>
      <% end %>
    </div>
    """
  end
end
