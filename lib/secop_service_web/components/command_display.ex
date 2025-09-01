defmodule SecopServiceWeb.Components.CommandDisplay do
  use Phoenix.LiveComponent

  require Logger

  alias SecopService.NodeControl
  alias NodeTable
  import SecopServiceWeb.CoreComponents
  alias SecopService.Util
  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(
        %{
          class: class,
          host: host,
          port: port,
          module_name: module_name,
          command: command,
          location: location,
          id_str: id_str
        } = _assigns,
        socket
      ) do
    has_arg = Map.has_key?(command.datainfo, "argument") and command.datainfo["argument"] != nil

    arg_dtype =
      cond do
        has_arg -> Jason.encode!(command.datainfo["argument"], pretty: true)
        true -> nil
      end

    node_id = {String.to_charlist(host), port}

    arg_form =
      to_form(%{
        "location" => "#{location}",
        "host" => to_string(host),
        "port" => Integer.to_string(port),
        "command" => command.name,
        "module" => module_name,
        "value" => nil
      })

    socket =
      socket
      |> assign(:command, command)
      |> assign(:module_name, module_name)
      |> assign(:node_id, node_id)
      |> assign(:host, host)
      |> assign(:port, port)
      |> assign(:class, class)
      |> assign(:location, location)
      |> assign(:show_arg_modal, false)
      |> assign(:arg_form, arg_form)
      |> assign(:return, nil)
      |> assign(:arg_dtype, arg_dtype)
      |> assign(:has_arg, has_arg)
      |> assign(:command_success, nil)
      |> assign(:id_str, id_str)

    {:ok, socket}
  end

  def update(%{action: :clear_highlight} = _assigns, socket) do
    Logger.info("reset cmd success")
    socket = assign(socket, :command_success, nil)

    {:ok, socket}
  end

  def update(%{return_value: return_val} = _assigns, socket) do
    Logger.info("indicate command success")

    socket =
      case return_val do
        {:done, _module, _command, _data_report} ->
          send(self(), {:put_flash, [:info, "#{inspect(return_val)}"]})
          assign(socket, :command_success, "done")

        {:error, :do, _specifier, _error_class, _error_text, _error_dict} ->
          send(self(), {:put_flash, [:error, "#{inspect(return_val)}"]})
          assign(socket, :command_success, "error")
      end

    send_update_after(__MODULE__, %{id: socket.assigns.id_str, action: :clear_highlight}, 1000)

    {:ok, socket}
  end

  def handle_event("validate_arg", params, socket) do
    Logger.info("Validating cmd arg #{params["command"]} with value #{params["value"]}")

    updated_arg_form =
      NodeControl.validate(
        params,
        socket.assigns.command.datainfo["argument"],
        socket.assigns.arg_form
      )

    {:noreply, assign(socket, :arg_form, updated_arg_form)}
  end

  def handle_event("set_arg", params, socket) do
    Logger.info("Sending command #{params["command"]} with arg #{params["value"]}")

    # TODO: handle return_val properly
    # set command_success based on return_val
    pid = self()

    Task.start(fn ->
      return_val = NodeControl.execute_command(params)
      Logger.info("NodeControl.execute_command returned: #{inspect(return_val)}")

      send_update(pid, __MODULE__, %{id: socket.assigns.id_str, return_value: return_val})
    end)

    {:noreply, assign(socket, :command_success, "running")}
  end

  @impl true
  def handle_event("open_arg_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_arg_modal: true
     )}
  end

  @impl true
  def handle_event("close_arg_modal", _params, socket) do
    {:noreply, assign(socket, show_arg_modal: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @has_arg  do %>
        <button
          phx-click="open_arg_modal"
          phx-target={@myself}
          class="font-mono font-semibold pr-4 pl-4 rounded-lg p-1  border border-stone-500 text-gray-700 dark:text-gray-300  hover:bg-zinc-400 dark:hover:bg-zinc-700 command_item"
        >
          {Util.display_name(@command.name)}
        </button>

        <.modal
          :if={@show_arg_modal}
          id="arg-modal"
          title={Util.display_name(@command.name)}
          show={@show_arg_modal}
          on_cancel={JS.push("close_arg_modal", target: @myself)}
        >
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-xl  p-6">
            <pre class="break-words max-h-[60vh] border p-4 m-2 overflow-y-auto bg-gray-100 dark:bg-zinc-800 text-gray-800 dark:text-gray-200 font-mono text-xs p-2 rounded-lg ">{@arg_dtype}</pre>
            <.form
              for={@arg_form}
              phx-submit="set_arg"
              phx-change="validate_arg"
              phx-target={@myself}
              class="flex space-x-2"
            >
              <input
                type="hidden"
                name="port"
                value={Phoenix.HTML.Form.input_value(@arg_form, :port)}
              />
              <input
                type="hidden"
                name="host"
                value={Phoenix.HTML.Form.input_value(@arg_form, :host)}
              />
              <input
                type="hidden"
                name="location"
                value={Phoenix.HTML.Form.input_value(@arg_form, :location)}
              />
              <input
                type="hidden"
                name="module"
                value={Phoenix.HTML.Form.input_value(@arg_form, :module)}
              />
              <input type="hidden" name="command" value={@command.name} />
              <.input
                name="value"
                type="text"
                field={@arg_form[:value]}
                placeholder="arg value"
                phx-debounce="500"
                id={"form:" <> to_string(@command.id)}
                class="flex-1 max-h-80 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2 border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
              />
              <button
                type="submit"
                class="font-mono font-semibold pr-4 pl-4 rounded-lg p-1  border border-stone-500 text-gray-700 dark:text-gray-300  hover:bg-zinc-400 dark:hover:bg-zinc-700 command_item"
              >
                Send
              </button>
            </.form>
          </div>
        </.modal>
      <% else %>
        <.form
          for={@arg_form}
          phx-submit="set_arg"
          phx-change="validate_arg"
          phx-target={@myself}
          class="flex space-x-2"
        >
          <input type="hidden" name="port" value={Phoenix.HTML.Form.input_value(@arg_form, :port)} />
          <input type="hidden" name="host" value={Phoenix.HTML.Form.input_value(@arg_form, :host)} />
          <input
            type="hidden"
            name="location"
            value={Phoenix.HTML.Form.input_value(@arg_form, :location)}
          />
          <input
            type="hidden"
            name="module"
            value={Phoenix.HTML.Form.input_value(@arg_form, :module)}
          />
          <input type="hidden" name="command" value={@command.name} />
          <input type="hidden" name="value" value={nil} />
          <button
            type="submit"
            class="font-mono font-semibold pr-4 pl-4 rounded-lg p-1  border border-stone-500 text-gray-700 dark:text-gray-300  hover:bg-zinc-400 dark:hover:bg-zinc-700 command_item"
            mod-highlight={@command_success}
          >
            {Util.display_name(@command.name)}
          </button>
        </.form>
      <% end %>
    </div>
    """
  end
end
