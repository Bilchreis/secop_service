defmodule SecopServiceWeb.Components.ModuleIndicator do
  use Phoenix.LiveComponent

  require Logger

  alias NodeTable
  alias SecopService.Util
  alias SecopService.NodeValues
  alias SecopServiceWeb.SECoPComponents

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  defp get_status_value(module_name, node_id, status_param) do
    stat_val =
      if status_param != nil do
        stat_val =
          case NodeTable.lookup(
                 {:service, node_id},
                 {:data_report, String.to_existing_atom(module_name), :status}
               ) do
            {:ok, data_report} ->
              data_report

            {:error, :notfound} ->
              Logger.warning(
                "Data report for module #{module_name} and parameter status not found in NodeTable for node #{inspect(node_id)}}."
              )

              NodeValues.process_data_report(status_param.name, nil, status_param.datainfo)
          end

        stat_val
      else
        nil
      end

    stat_val
  end

  @impl true
  def update(
        %{
          host: host,
          port: port,
          module_name: module_name,
          highest_if_class: highest_if_class,
          status_param: status_param,
          node_state: node_state,
          indicator_select: indicator_select
        } = _assigns,
        socket
      ) do
    node_id = {String.to_charlist(host), port}

    socket =
      socket
      |> assign(:highest_if_class, highest_if_class)
      |> assign(:status_param, status_param)
      |> assign(:module_name, module_name)
      |> assign(:node_state, node_state)
      |> assign(:node_id, node_id)
      |> assign(:indicator_select, indicator_select)
      |> assign_new(:status_value, fn -> get_status_value(module_name, node_id, status_param) end)

    {:ok, socket}
  end

  @impl true
  def update(%{value_update: processed_value_update} = _assigns, socket) do
    {:ok, assign(socket, :status_value, processed_value_update)}
  end

  attr :status_value, :map, required: true

  def inner_status_indicator(assigns) do
    assigns =
      if assigns.status_value.data_report == nil do
        assign(assigns, :stat_col, "bg-neutral")
      else
        assign(
          assigns,
          :stat_col,
          SECoPComponents.status_to_color(assigns.status_value.stat_color)
        )
      end

    ~H"""
    <div class="flex items-center">
      <div class={[@stat_col, "w-6 h-6 mr-2 rounded-full border-3 border-gray-500/70"]}></div>
      <div class="mb-1">
        <%= if @status_value.data_report != nil do %>
          <div class="text-lg font-semibold text-neutral-content truncate">
            {@status_value.stat_code}
          </div>
        <% end %>
      </div>
    </div>
    <%= if @status_value.data_report != nil do %>
      <div class="text-neutral-content">
        {@status_value.stat_string}
      </div>
    <% else %>
      <div class="text-sm text-neutral-content opacity-60">
        waiting for data...
      </div>
    <% end %>
    """
  end

  attr :module_name, :string, required: true
  attr :node_state, :atom, required: true
  attr :status_value, :map, required: true

  def module_indicator_status(assigns) do
    display_name = Util.display_name(assigns.module_name)
    # Adjust this threshold based on your needs (characters that fit in w-48)
    text_too_long = String.length(display_name) > 20

    color =
      case assigns.node_state do
        :connected -> "bg-warning text-warning-content"
        :disconnected -> "bg-error text-error-content"
        :initialized -> "bg-neutral text-neutral-content"
        # default fallback
        _ -> "bg-error text-error-content"
      end

    stat_col =
      if assigns.status_value.data_report != nil do
        SECoPComponents.status_to_color(assigns.status_value.stat_color)
      else
        "bg-warning text-warning-content"
      end

    show =
      if text_too_long do
        "overflow-hidden"
      else
        "truncate"
      end

    animate_marquee =
      if text_too_long do
        "animate-marquee hover:pause-animation"
      else
        ""
      end

    assigns =
      assigns
      |> assign(:display_name, display_name)
      |> assign(:color, color)
      |> assign(:stat_col, stat_col)
      |> assign(:show, show)
      |> assign(:animate_marquee, animate_marquee)

    ~H"""
    <div class={[
      "card",
      "w-[300px]",
      "text-left font-bold py-2 px-4",
      @color
    ]}>
      <div class="flex items-center">
        <div class={[@stat_col, "w-6 h-6 mr-2 rounded-full border-3 border-gray-500/70"]}></div>

        <div class="flex-1 min-w-0">
          <div class={[
            "text-xl",
            @show
          ]}>
            <div
              class={[
                "whitespace-nowrap",
                @animate_marquee
              ]}
              title={@display_name}
            >
              {@display_name}
            </div>
          </div>
          <%= if @status_value.data_report != nil do %>
            <div class="text-sm opacity-60 truncate">
              {@status_value.stat_code} : {@status_value.stat_string}
            </div>
          <% else %>
            <div class="text-sm opacity-60">
              waiting for data...
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :module_name, :string, required: true
  attr :node_state, :atom, required: true

  def module_indicator(assigns) do
    display_name = Util.display_name(assigns.module_name)
    # Adjust this threshold based on your needs (characters that fit in w-48)
    text_too_long = String.length(display_name) > 20

    color =
      case assigns.node_state do
        :connected -> "bg-warning text-warning-content"
        :disconnected -> "bg-error text-error-content"
        :initialized -> "bg-neutral text-neutral-content"
        # default fallback
        _ -> "bg-error text-error-content"
      end

    assigns = assign(assigns, :display_name, display_name)
    assigns = assign(assigns, :text_too_long, text_too_long)
    assigns = assign(assigns, :color, color)

    ~H"""
    <div class={[
      "card",
      "w-[300px]",
      "text-left font-bold py-2 px-4",
      @color
    ]}>
      <div class="flex items-center">
        <div class= "bg-base-100/10 w-6 h-6 mr-2 rounded-full border-3 border-gray-500/20"></div>
        <div class="flex-1 min-w-0">
          <div class={[
            "text-xl",
            if(@text_too_long, do: "overflow-hidden", else: "truncate")
          ]}>
            <div
              class={[
                "whitespace-nowrap",
                if(@text_too_long, do: "animate-marquee hover:pause-animation", else: "")
              ]}
              title={@display_name}
            >
              {@display_name}
            </div>
          </div>
          <div class="text-sm text-white-400 opacity-0">
            placeholder
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= case @indicator_select do %>
        <% :outer -> %>
          <%= if @status_param do %>
            <.module_indicator_status
              module_name={@module_name}
              node_state={@node_state}
              status_value={@status_value}
            />
          <% else %>
            <.module_indicator module_name={@module_name} node_state={@node_state} />
          <% end %>
        <% :inner -> %>
          <.inner_status_indicator status_value={@status_value} />
      <% end %>
    </div>
    """
  end
end
