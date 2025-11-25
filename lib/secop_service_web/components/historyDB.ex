defmodule SecopServiceWeb.Components.HistoryDB do
  use Phoenix.LiveComponent
  import SecopServiceWeb.CoreComponents
  require Logger
  alias SecopService.PlotDB
  alias SecopService.Sec_Nodes
  alias SecopService.Sec_Nodes.ParameterValue
  alias Phoenix.LiveView.JS

  defp get_tabledata(secop_obj, params \\ %{}) do
    case get_parameter(secop_obj) |> Sec_Nodes.list_parameter_values(params) do
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

  defp get_parameter(secop_obj) do
    case secop_obj do
      %SecopService.Sec_Nodes.Parameter{} = param ->
        param

      %SecopService.Sec_Nodes.Module{} = module ->
        Enum.find(module.parameters, nil, fn param -> param.name == "value" end)
    end
  end

  def tabular?(%SecopService.Sec_Nodes.Module{} = module) do
    if get_parameter(module) do
      true
    else
      false
    end
  end

  def tabular?(%SecopService.Sec_Nodes.Parameter{} = _parameter) do
    true
  end

  @impl true
  def update(%{secop_obj: secop_obj} = assigns, socket) do
    initialized = socket.assigns[:initialised] || false

    socket =
      if initialized do
        socket
      else
        socket =
          socket
          |> assign(:table_data, nil)
          |> assign(:plot, nil)

        socket =
          cond do
            PlotDB.plottable?(secop_obj) ->
              assign(socket, :display_mode, :graph)
              |> assign(:plottable, true)
              |> assign_async(:plot, fn -> {:ok, %{plot: PlotDB.init(secop_obj)}} end)

            tabular?(secop_obj) ->
              assign(socket, :display_mode, :table)
              |> assign(:plottable, false)
              |> assign_async(:table_data, fn -> get_tabledata(secop_obj) end)

            true ->
              assign(socket, :display_mode, :empty)
              |> assign(:plottable, false)
          end

        socket
        |> assign(:initialised, true)
        |> assign(:id, assigns.id)
        |> assign(:class, assigns.class)
        |> assign(:parameter, get_parameter(secop_obj))
        |> assign(:secop_obj, secop_obj)
      end

    {:ok, socket}
  end

  def update(%{value_update: value_update_list, parameter: parameter} = _assigns, socket) do
    param_list =
      case socket.assigns.secop_obj do
        %SecopService.Sec_Nodes.Parameter{} = param ->
          [param.name]

        %SecopService.Sec_Nodes.Module{} = module ->
          case module.highest_interface_class do
            "readable" -> ["value"]
            "drivable" -> ["value", "target"]
            "communicator" -> []
            "acquisition" -> ["value"]
            _ -> []
          end
      end

    socket =
      if socket.assigns.plottable and parameter in param_list and socket.assigns.plot.ok? do
        validated_datapoints =
          Enum.reduce(value_update_list, [], fn [value, qualifiers], acc ->
            case qualifiers do
              %{t: timestamp} ->
                # Convert to milliseconds if needed
                timestamp = trunc(timestamp * 1000)
                [{value, timestamp} | acc]

              _ ->
                acc
            end
          end)
          |> Enum.reverse()

        if length(validated_datapoints) > 0 do
          update_data =
            PlotDB.get_trace_updates_batch(
              socket.assigns.plot.result,
              validated_datapoints,
              parameter
            )

          push_event(socket, "extend-traces-#{socket.assigns.id}", update_data)
        else
          socket
        end
      else
        socket
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
    socket =
      assign_async(socket, :table_data, fn ->
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

    direction_atom =
      case current_meta.flop.order_by do
        [^field_atom | _] ->
          # If the field is already sorted, toggle the direction
          if current_meta.flop.order_directions == [:asc], do: :desc, else: :asc

        _ ->
          # If a different field is sorted, set the new field and default to ascending
          :asc
      end

    # Update the meta with new sort params
    params =
      Map.put(old_params, :order_by, [field_atom]) |> Map.put(:order_directions, [direction_atom])

    secop_obj = socket.assigns.parameter

    socket =
      assign_async(socket, :table_data, fn ->
        get_tabledata(secop_obj, params)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("set-display-mode", %{"mode" => mode}, socket) do
    display_mode = String.to_existing_atom(mode)
    secop_obj = socket.assigns.secop_obj

    socket =
      case display_mode do
        :graph ->
          if socket.assigns.plot == nil do
            socket |> assign_async(:plot, fn -> {:ok, %{plot: PlotDB.init(secop_obj)}} end)
          else
            socket
          end

        :table ->
          if socket.assigns.table_data == nil do
            socket |> assign_async(:table_data, fn -> get_tabledata(secop_obj) end)
          else
            socket
          end

        _ ->
          socket
      end

    {:noreply, assign(socket, :display_mode, display_mode)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["flex flex-1", assigns[:class]]}>
      <%= if @display_mode != :empty  do %>
        <div class="flex space-x-2 mb-2">
          <button
            class={[
              "btn btn-neutral",
              @display_mode == :graph &&
                "btn-active btn-primary",
              @plottable == false &&
                "btn-disabled"
            ]}
            phx-click={JS.push("set-display-mode", value: %{mode: "graph"}, target: @myself)}
          >
            <div class="flex items-center">
              <.icon name="hero-chart-bar-solid" class="h-5 w-5 flex-none mr-1" /> Graph
            </div>
          </button>

          <button
            class={[
              "btn btn-neutral",
              @display_mode == :table &&
                "btn-active btn-primary"
            ]}
            phx-click={JS.push("set-display-mode", value: %{mode: "table"}, target: @myself)}
          >
            <div class="flex items-center">
              <.icon name="hero-table-cells-solid" class="h-5 w-5 flex-none mr-1" /> Table
            </div>
          </button>
        </div>
      <% end %>

      <%= case @display_mode do %>
        <% :graph -> %>
          <%= if @plottable do %>
            <.async_result :let={_plot} assign={@plot}>
              <:loading>
                <div class="flex flex-1 h-[340px] animate-pulse items-center justify-center text-center bg-gray-300 p-4 rounded-lg">
                  <span class="text-gray-700">Waiting for valid Plot Data...</span>
                </div>
              </:loading>
              <:failed>
                ERROR
              </:failed>

              <div class="flex-1 bg-gray-300 p-1 rounded-lg">
                <!-- Loading overlay - will be hidden by the JS hook when Plotly is ready -->
                <div
                  id={"#{@id}-loading"}
                  class="flex flex-1 h-[340px] items-center justify-center bg-gray-300  rounded-lg"
                >
                  <div class="text-center animate-pulse">
                    <p class="text-gray-700">Initializing chart...</p>
                  </div>
                </div>

                <div
                  id={@id}
                  class=""
                  phx-hook="PlotlyChart"
                  phx-update="ignore"
                  data-loading-id={"#{@id}-loading"}
                >
                </div>
              </div>
            </.async_result>
          <% else %>
            <div class="flex items-center justify-center h-[340px] text-center bg-gray-300 p-4 rounded-lg">
              <span class="text-gray-800">Data not plottable</span>
            </div>
          <% end %>
        <% :table -> %>
          <.async_result :let={table_data} assign={@table_data}>
            <:loading>
              <div class="animate-pulse w-full border-collapse border border-slate-300 dark:border-slate-600 text-gray-700 dark:text-gray-200">
                <table class="w-full">
                  <thead class="p-2 bg-gray-50 dark:bg-gray-800 border border-slate-300 dark:border-slate-600">
                    <tr>
                      <th class="p-2">Time</th>
                      <th class="p-2">Value</th>
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
            <div class="card bg-neutral rounded-lg  p-2">
              <Flop.Phoenix.table
                items={table_data.parameter_values}
                meta={table_data.meta}
                on_sort={JS.push("sort", target: @myself)}
                opts={table_opts()}
                id={"#{@id}-table"}
              >
                <:col :let={parameter_value} label="Time" field={:timestamp}>
                  {parameter_value.timestamp
                  |> DateTime.from_naive!("Etc/UTC")
                  |> DateTime.shift_zone!("Europe/Berlin")
                  |> Calendar.strftime("%d.%m.%Y %H:%M:%S.%f")}
                </:col>
                <:col :let={parameter_value} label="Value" field={:value}>
                  <div class="w-full max-w-1/2 font-mono truncate">
                    {ParameterValue.get_display_value(parameter_value, @parameter)}
                  </div>
                </:col>
              </Flop.Phoenix.table>

              <Flop.Phoenix.pagination
                meta={table_data.meta}
                on_paginate={JS.push("paginate", target: @myself)}
                page_links={10}
                class="flex flex-wrap items-center justify-center gap-y-2 gap-x-2 p-2 bg-neutral text-neutral-content "
                page_list_attrs={[class: "order-1 flex gap-1 basis-full justify-center"]}
                current_page_link_attrs={[class: "btn btn-primary"]}
                page_link_attrs={[
                  class: "btn btn-base-100"
                ]}
              >
                <:previous attrs={[
                  class: "order-2 btn btn-base-100"
                ]}>
                  Prev
                </:previous>

                <:next attrs={[
                  class: "order-2 btn btn-base-100"
                ]}>
                  Next
                </:next>
              </Flop.Phoenix.pagination>
            </div>
          </.async_result>
        <% :empty -> %>
          <!-- Nothing is rendered here, for example communicator modules
            that do not have a main param like value -->

        <% _ -> %>
          <div class="flex items-center justify-center h-full text-center bg-gray-300 p-4 rounded-lg">
            <span class="text-gray-800">Unknown display mode</span>
          </div>
      <% end %>
    </div>
    """
  end
end
