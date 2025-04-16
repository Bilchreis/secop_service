defmodule SecopServiceWeb.Components.PlotlyChartDB do
  use Phoenix.LiveComponent
  require Logger
  alias PlotPublisher
  alias SecopService.PlotDB

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{secop_obj: secop_obj} = assigns, socket) do
    initialized = socket.assigns[:initialised] || false

    socket =
      if initialized do
        socket
      else
        socket
          |> assign(:plot, PlotDB.init(secop_obj))
          |> assign(:initialised, true)
          |> assign(:id, assigns.id)
          |> assign(:class, assigns.class)
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
    <div class={["h-full ",assigns[:class]]}>
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
