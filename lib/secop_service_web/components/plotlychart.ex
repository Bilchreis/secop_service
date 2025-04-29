defmodule SecopServiceWeb.Components.PlotlyChart do
  use Phoenix.LiveComponent
  require Logger
  alias PlotPublisher
  alias SecopServiceWeb.DashboardLive.Plot

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{secop_obj: secop_obj, path: path} = assigns, socket) do
    initialized = socket.assigns[:initialised] || false

    socket =
      if initialized do
        socket
      else
        socket =
          case path do
            {host, port, module, parameter} ->
              parmam_topic = "#{host}:#{port}:#{module}:#{parameter}"
              param_id = path

              secop_obj =
                Map.put(secop_obj, :parameter_id, param_id)
                |> Map.put(:parameter_topic, parmam_topic)

              assign(socket, :host, host)
              |> assign(:port, port)
              |> assign(:module, module)
              |> assign(:parameter, parameter)
              |> assign(:plot, Plot.init({:parameter, secop_obj}))
              |> assign(:id, assigns.id)

            {host, port, module} ->
              module_topic = "#{host}:#{port}:#{module}"
              module_id = path

              secop_obj =
                Map.put(secop_obj, :module_id, module_id) |> Map.put(:module_topic, module_topic)

              assign(socket, :host, host)
              |> assign(:port, port)
              |> assign(:module, module)
              |> assign(:plot, Plot.init({:module, secop_obj}))
              |> assign(:id, assigns.id)
          end

        socket = assign(socket, :initialised, true)

        topics = socket.assigns.plot.topics

        # Unsubscribe from old topics that aren't in the new list
        Enum.each(topics, fn topic ->
          Phoenix.PubSub.unsubscribe(:secop_client_pubsub, topic)
        end)

        # Subscribe only to new topics
        Enum.each(topics, fn topic ->
          Phoenix.PubSub.subscribe(:secop_client_pubsub, topic)
        end)

        socket
      end

    {:ok, socket}
  end

  def update(%{value_update: value_update, pubsub_topic: pubsub_topic} = _assigns, socket) do
    parameter = Enum.at(String.split(pubsub_topic, ":"), -1)

    [value, qualifiers] = value_update

    socket =
      case qualifiers do
        %{t: timestamp} ->
          timestamp = timestamp * 1000
          # Find the trace index based on the parameter name
          # This assumes traces are ordered by parameter name in plot.data
          trace_index =
            Enum.find_index(socket.assigns.plot.data, fn trace ->
              trace[:name] == parameter
            end) || 0

          # Format data for the extend-traces event
          # The event expects arrays of arrays (one per trace)
          update_data = %{
            # Add one timestamp to the specified trace
            x: [[timestamp]],
            # Add one value to the specified trace
            y: [[value]],
            traceIndices: [trace_index]
          }

          # Push the event to the client
          push_event(socket, "extend-traces-#{socket.assigns.id}", update_data)

        _ ->
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("request-plotly-data", %{"id" => _chart_id}, %{assigns: assigns} = socket) do
    {:noreply,
     push_event(socket, "plotly-data-#{socket.assigns.id}", %{
       data: assigns.plot.data,
       layout: assigns.plot.layout,
       config: assigns.plot.config
     })}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full">
      <%= if @plot.plottable do %>
        <%= if @plot.plot_available do %>
          <div class="bg-gray-300 p-4 rounded-lg h-full">
            <div id={@id} class="w-full h-full" phx-hook="PlotlyChart" phx-update="ignore">
              <!-- Plotly will render here -->
            </div>
          </div>
        <% else %>
          <div class="animate-pulse flex items-center justify-center h-full text-center bg-gray-300 p-4 rounded-lg">
            <p>Waiting for plottable Data</p>
          </div>
        <% end %>
      <% else %>
        <div class="flex items-center justify-center h-80 text-center bg-gray-300 p-4 rounded-lg">
          <p>Data not Plottable</p>
        </div>
      <% end %>
    </div>
    """
  end
end
