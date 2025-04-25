defmodule SecopServiceWeb.Components.HistoryDB do
  use Phoenix.LiveComponent
  import SecopServiceWeb.CoreComponents
  require Logger
  alias PlotPublisher
  alias SecopService.PlotDB
  alias SecopService.Sec_Nodes
  alias SecopService.Sec_Nodes.ParameterValue
  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  defp get_parameter_id(secop_obj) do
      get_parameter(secop_obj)
      |> Map.get(:id)
  end

  defp get_parameter(secop_obj) do
    case secop_obj do
      %SecopService.Sec_Nodes.Parameter{} = param ->
        param
      %SecopService.Sec_Nodes.Module{} = module ->
        Enum.find(module.parameters, fn param -> param.name == "value" end)
    end
  end

  @impl true
  def update(%{secop_obj: secop_obj} = assigns, socket) do
    initialized = socket.assigns[:initialised] || false

    socket =
      if initialized do
        socket
      else
        plot_map = PlotDB.init(secop_obj)
        {:ok, {paramerter_values, meta}} = get_parameter_id(secop_obj) |> Sec_Nodes.list_parameter_values()


        socket
          |> assign(:plot, plot_map)
          |> assign(:initialised, true)
          |> assign(:id, assigns.id)
          |> assign(:class, assigns.class)
          |> assign(:display_mode, if(plot_map.plottable, do: :graph, else: :table))
          |> assign(:parameter, get_parameter(secop_obj))
          |> assign(:param_values, paramerter_values)
          |> assign(:meta, meta)


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
      <div class={["h-full flex", assigns[:class]]}>
        <!-- Main content area - plot -->

        <div class="flex-grow h-full">
          <%= case @display_mode do %>
            <% :graph -> %>
              <%= if @plot.plottable do %>
                <%= if @plot.plot_available do %>
                  <div class="bg-gray-300 p-4 rounded-lg h-full relative" style="min-height: 400px;">
                    <!-- Loading overlay - will be hidden by the JS hook when Plotly is ready -->
                    <div id={"#{@id}-loading"} class="absolute inset-0 flex items-center justify-center bg-gray-300  rounded-lg">
                      <div class="text-center animate-pulse">
                          <p class="text-gray-700">Initializing chart...</p>
                      </div>
                    </div>

                    <div id={@id} class="w-full h-full" phx-hook="PlotlyChart" phx-update="ignore" data-loading-id={"#{@id}-loading"}>
                      <!-- Plotly will render here -->
                    </div>
                  </div>
                <% else %>
                  <div class="animate-pulse flex items-center justify-center h-full text-center bg-gray-300 p-4 rounded-lg" style="min-height: 400px;">
                    <p>Waiting for plottable Data</p>
                  </div>
                <% end %>
              <% else %>
                  <div class="flex items-center justify-center h-full text-center bg-gray-300 p-4 rounded-lg" style="min-height: 400px;">
                    <span class="text-gray-700">Data not Plottable</span>
                  </div>
              <% end %>

              <% :table -> %>
                <Flop.Phoenix.table
                  items={@param_values}
                  meta={@meta}
                  on_sort={
                    JS.dispatch("my_app:scroll_to", to: "#pet-table") |> JS.push("sort")
                    }
                  opts={table_opts()}>
                  <:col :let={parameter_value} label="Time" field={:timestamp}>
                    {parameter_value.timestamp
                    |> DateTime.from_naive!("Etc/UTC")
                    |> DateTime.shift_zone!("Europe/Berlin")
                    |> Calendar.strftime("%d.%m.%Y %H:%M")}
                  </:col>
                  <:col :let={parameter_value} label="Value" field={:value}>
                    <span class="font-mono">{ParameterValue.get_display_value(parameter_value,@parameter)}</span>
                  </:col>
                </Flop.Phoenix.table>
          <% end %>
        </div>

        <!-- Button sidebar on the right -->
        <div class="ml-4 flex flex-col space-y-2 h-full">
          <button class="px-4 py-2 bg-gray-300 dark:bg-gray-600  dark:text-white rounded-lg hover:bg-gray-400 dark:hover:bg-gray-700 focus:outline-none">
            <div class="flex items-center">
              <.icon name="hero-chart-bar-solid" class=" h-5 w-5 flex-none mr-1" />
              Graph
            </div>
          </button>

          <button class="px-4 py-2 bg-stone-300 dark:bg-stone-600 dark:text-white rounded-lg hover:bg-stone-400 dark:hover:bg-stone-700 focus:outline-none">
            <div class="flex items-center">
              <.icon name="hero-table-cells-solid" class=" h-5 w-5 flex-none mr-1" />
              Table
            </div>
          </button>
        </div>
      </div>
    """
  end
end
