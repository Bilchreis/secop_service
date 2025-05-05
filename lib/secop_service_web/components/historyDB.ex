defmodule SecopServiceWeb.Components.HistoryDB do
  use Phoenix.LiveComponent
  import SecopServiceWeb.CoreComponents
  require Logger
  alias PlotPublisher
  alias SecopService.PlotDB
  alias SecopService.Sec_Nodes
  alias SecopService.Sec_Nodes.ParameterValue
  alias Phoenix.LiveView.JS

  defp get_tabledata(secop_obj, params \\ %{}) do


    case get_parameter_id(secop_obj) |> Sec_Nodes.list_parameter_values(params) do
      {:ok, {parameter_values, meta}} ->
        {:ok, %{table_data: %{parameter_values: parameter_values, meta: meta}}}
      {:error, reason} ->
        Logger.error("Error fetching parameter values: #{inspect(reason)}")
        {:error, reason}

    end

  end

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


        socket = if PlotDB.get_parameter(secop_obj) |> PlotDB.plottable?() do
          assign(socket, :display_mode,:graph)
          |> assign(:plottable, true)
        else
          assign(socket, :display_mode,:table)
          |> assign(:plottable, false)
        end



        socket
          |> assign_async(:plot, fn -> {:ok, %{plot: PlotDB.init(secop_obj)}} end)
          |> assign_async(:table_data, fn -> get_tabledata(secop_obj)end)
          |> assign(:initialised, true)
          |> assign(:id, assigns.id)
          |> assign(:class, assigns.class)
          |> assign(:parameter, get_parameter(secop_obj))

      end



    {:ok, socket}
  end


  @impl true
  def handle_event("request-plotly-data", %{"id" => _chart_id}, %{assigns: assigns} = socket) do

    {:noreply,
     push_event(socket, "plotly-data-#{socket.assigns.id}", %{
       data: assigns.plot.result.data,
       layout: assigns.plot.result.layout,
       config: assigns.plot.result.config
     })}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    %{parameter_values: _paramerter_values, meta: current_meta} = socket.assigns.table_data.result
    old_params = current_meta.params

    page = Integer.parse(page) |> elem(0)

    # Update the meta with new sort params
    params = Map.put(old_params, :page, page)

    secop_obj = socket.assigns.parameter

    # Fetch data with new sort parameters
    socket = assign_async(socket, :table_data, fn ->
      get_tabledata(secop_obj, params)
    end)

    {:noreply, socket}

  end

  @impl true
  def handle_event("sort", %{"order" => order}, socket) do
    %{parameter_values: _paramerter_values, meta: current_meta} = socket.assigns.table_data.result

    old_params = current_meta.params

    # Convert to atoms for Flop
    field_atom = String.to_existing_atom(order)

    direction_atom = case current_meta.flop.order_by do
      [^field_atom | _] ->
        # If the field is already sorted, toggle the direction
        if current_meta.flop.order_directions == [:asc], do: :desc, else: :asc
      _ ->
        # If a different field is sorted, set the new field and default to ascending
        :asc
    end

    # Update the meta with new sort params
    params = Map.put(old_params, :order_by, [field_atom]) |> Map.put(:order_directions, [direction_atom])

    secop_obj = socket.assigns.parameter

    socket = assign_async(socket, :table_data, fn ->
      get_tabledata(secop_obj, params)
    end)

    {:noreply, socket}

  end

  @impl true
  def handle_event("set-display-mode", %{"mode" => mode}, socket) do
    display_mode = String.to_existing_atom(mode)
    {:noreply, assign(socket, :display_mode, display_mode)}
  end






  @impl true
  def render(assigns) do



    ~H"""
      <div class={["h-full flex", assigns[:class]]}>
        <!-- Main content area - plot -->

        <div class="flex-grow h-full">
          <%= case @display_mode do %>
            <% :graph -> %>
              <%= if @plottable do %>
                <.async_result :let={_plot} assign={@plot}>
                  <:loading>
                    <div class="animate-pulse flex items-center justify-center h-full text-center bg-gray-300 p-4 rounded-lg" style="min-height: 400px;">
                      <p>Waiting for plottable Data</p>
                    </div>
                  </:loading>
                  <:failed>
                    ERROR
                  </:failed>

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
                </.async_result>
              <% else %>
                <div class="flex items-center justify-center h-full text-center bg-gray-300 p-4 rounded-lg" style="min-height: 400px;">
                    <span class = "text-gray-800">Data not plottable</span>
                </div>
              <% end %>


              <% :table -> %>
                <.async_result :let={table_data} assign={@table_data}>
                <:loading>
                    <div class="animate-pulse w-full border-collapse border border-slate-300 dark:border-slate-600 text-gray-700 dark:text-gray-200" style="min-height: 400px;">
                      <table class="w-full">
                        <thead class =  "p-2 bg-gray-50 dark:bg-gray-800 border border-slate-300 dark:border-slate-600">
                          <tr>
                            <th class = "p-2">Time</th>
                            <th class = "p-2">Value</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for _i <- 1..10 do %>
                            <tr class="border-b border-gray-200">
                              <td class="p-2">
                                <div class="h-6 bg-gray-400 rounded w-28"></div>
                              </td>
                              <td class="p-2">
                                <div class="h-6 bg-gray-400 rounded w-20"></div>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </:loading>
                  <:failed>
                    ERROR
                  </:failed>
                <Flop.Phoenix.table
                  items={table_data.parameter_values}
                  meta={table_data.meta}
                  on_sort={
                    JS.push("sort", target: @myself)
                    }
                  opts={table_opts()}>
                  <:col :let={parameter_value} label="Time" field={:timestamp}>
                    {parameter_value.timestamp
                    |> DateTime.from_naive!("Etc/UTC")
                    |> DateTime.shift_zone!("Europe/Berlin")
                    |> Calendar.strftime("%d.%m.%Y %H:%M:%S.%f")}
                  </:col>
                  <:col :let={parameter_value} label="Value" field={:value}>
                    <span class="font-mono">{ParameterValue.get_display_value(parameter_value,@parameter)}</span>
                  </:col>
                </Flop.Phoenix.table>

                <Flop.Phoenix.pagination
                  meta={table_data.meta}
                  on_paginate={JS.push("paginate", target: @myself)}
                  page_links={10}
                  opts={node_browser_pagination_opts()}  />
                </.async_result>


          <% end %>
        </div>


        <!-- Button sidebar on the right -->
        <div class="ml-4 flex flex-col space-y-2 h-full">
          <button class={[
            "px-4 py-2 rounded-lg focus:outline-none",
            @display_mode == :graph && "bg-gray-500 text-white hover:bg-gray-600 dark:bg-purple-700 dark:hover:bg-gray-800",
            @display_mode != :graph && "bg-gray-300 dark:bg-gray-600 dark:text-white hover:bg-gray-400 dark:hover:bg-gray-700"
          ]}
            phx-click={JS.push("set-display-mode", value: %{mode: "graph"}, target: @myself)}>
            <div class="flex items-center">
              <.icon name="hero-chart-bar-solid" class="h-5 w-5 flex-none mr-1" />
              Graph
            </div>
          </button>

          <button class={[
            "px-4 py-2 rounded-lg focus:outline-none",
            @display_mode == :table && "bg-stone-500 text-white hover:bg-stone-600 dark:bg-purple-700 dark:hover:bg-stone-800",
            @display_mode != :table && "bg-stone-300 dark:bg-stone-600 dark:text-white hover:bg-stone-400 dark:hover:bg-stone-700"
          ]}
            phx-click={JS.push("set-display-mode", value: %{mode: "table"}, target: @myself)}>
            <div class="flex items-center">
              <.icon name="hero-table-cells-solid" class="h-5 w-5 flex-none mr-1" />
              Table
            </div>
          </button>
        </div>
      </div>
    """
  end
end
