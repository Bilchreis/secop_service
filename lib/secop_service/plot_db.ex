defmodule SecopService.PlotDB do
  alias SecopService.Util
  alias SecopService.Sec_Nodes
  require Logger

  @max_retries 3
  # milliseconds
  @retry_delay 4000

  defp get_values_with_retry(param_id, retries \\ 0) do
    values = Sec_Nodes.get_values(param_id)

    case values do
      [] when retries < @max_retries ->
        :timer.sleep(@retry_delay)
        get_values_with_retry(param_id, retries + 1)

      _ ->
        values
    end
  end

  def get_layout(%{plotly: nil} = plot_map) do
    layout = %{
      xaxis: %{
        title: %{text: "Time"},
        type: "date",
        rangeselector: %{
          buttons: [
            %{count: 1, label: "1m", step: "minute", stepmode: "backward"},
            %{count: 10, label: "10m", step: "minute", stepmode: "backward"},
            %{count: 30, label: "30m", step: "minute", stepmode: "backward"},
            %{count: 1, label: "1h", step: "hour", stepmode: "backward"},
            %{count: 1, label: "1d", step: "day", stepmode: "backward"},
            %{step: "all", label: "all"}
          ],
          active: 5,
          x: 0,
          y: 1.02,
          xanchor: "left",
          yanchor: "bottom"
        },
        rangeslider: %{visible: false}
      },
      yaxis: %{title: %{text: "#{plot_map.unit}"}},
      margin: %{t: 10, b: 40, l: 50, r: 20},
      # background color of the chart container space,
      paper_bgcolor: "rgba(0,0,0,0",
      ## background color of plot area
      plot_bgcolor: "rgba(0,0,0,0)",
      autosize: true,
      height: 310,

      # Add range slider toggle buttons positioned next to rangeselector
      updatemenus: [
        %{
          type: "buttons",
          direction: "left",
          buttons: [
            %{
              args: [%{"xaxis.rangeslider.visible" => false}],
              args2: [%{"xaxis.rangeslider.visible" => true}],
              label: "Range Selector",
              method: "relayout"
            }
          ],
          pad: %{r: 0, t: 0, l: 0, b: 0},
          showactive: false,
          x: 0.28,
          xanchor: "left",
          y: 0.99,
          yanchor: "bottom",
          # Transparent background
          bgcolor: "rgba(200,200,200,1)",
          font: %{size: 11}
        }
      ]
    }

    Map.put(plot_map, :layout, layout)
  end

  def get_layout(%{plotly: plotly} = plot_map) do
    layout = Map.get(plotly, "layout", [])

    Map.put(plot_map, :layout, layout)
  end

  defp get_element(value, path) do
    case path do
      [] ->
        value

      [key | tail] when is_binary(key) ->
        # Handle both string and atom keys
        result = Map.get(value, key) || Map.get(value, String.to_atom(key))
        get_element(result, tail)

      [index | tail] when is_integer(index) ->
        get_element(Enum.at(value, index), tail)
    end
  end


  defp map_to(key,nil), do: key

  defp map_to(key,map) do
    str_key = to_string(key)
    case Map.get(map, str_key,:not_found) do
      :not_found ->
        Logger.warning("Key #{inspect(str_key)} not found in map")
        nil
      value -> value
    end
  end

  defp default(value,nil) do
    value
  end

  defp default(value,default) do
    default
  end


  defp process_plot_data(raw_data, plotly_specifier) do
    {type, path} = Map.get(plotly_specifier, "path", []) |> List.pop_at(0)
    parameter = Map.get(plotly_specifier, "parameter", "")
    indices = Map.get(plotly_specifier, "indices", "all")
    mapping = Map.get(plotly_specifier, "map_to", nil)
    default = Map.get(plotly_specifier, "default", nil)



    data =
      raw_data
      |> Map.get(parameter, [])
      |> Map.get(type, [])


    extracted_data =
      case indices do
        "all" -> Enum.reduce(data, [], fn value, acc -> acc ++ [get_element(value, path) |> map_to(mapping) |> default(default)] end)
        0 -> Enum.at(data, 0) |> get_element(path) |> map_to(mapping) |> default(default)
      end

    extracted_data
  end

  # single parameter/readable with scalar data
  def get_data(%{plotly: nil} = plot_map, value_ts, value_val) do
    data = [
      %{
        x: value_ts,
        y: value_val,
        type: "scatter",
        mode: "lines",
        name: "value"
      }
    ]

    Map.put(plot_map, :data, data)
  end

  # readable/single parameter with plotly specification
  def get_data(%{plotly: plotly} = plot_map, value_ts, value_val) do
    raw_data = %{
      "value" => %{"timestamp" => value_ts, "value" => value_val}
    }

    data = Map.get(plotly, "data", [])

    data =
      Enum.reduce(data, [], fn trace, data_acc ->
        new_data =
          Enum.reduce(trace, %{}, fn {key, value}, acc ->
            acc = Map.put(acc, key, value)

            case value do
              # Plotly path and parameter
              %{"path" => _path, "parameter" => _parameter} ->
                Map.put(acc, key, process_plot_data(raw_data, value))

              # Standard plotly specifier
              _ ->
                Map.put(acc, key, value)
            end
          end)

        [new_data | data_acc]
      end)

    data = Enum.reverse(data)
    Map.put(plot_map, :data, data)
  end

  # drivable with scalar data
  def get_data(%{plotly: nil} = plot_map, value_ts, value_val, target_ts, target_val) do
    data = [
      %{
        x: value_ts,
        y: value_val,
        type: "scatter",
        mode: "lines",
        name: "value"
      },
      %{
        x: target_ts,
        y: target_val,
        type: "scatter",
        mode: "lines",
        name: "target"
      }
    ]

    Map.put(plot_map, :data, data)
  end

  # drivable with plotly specification
  def get_data(%{plotly: plotly} = plot_map, value_ts, value_val, target_ts, target_val) do
    raw_data = %{
      "value" => %{"timestamp" => value_ts, "value" => value_val},
      "target" => %{"timestamp" => target_ts, "value" => target_val}
    }

    data = Map.get(plotly, "data", [])

    data =
      Enum.reduce(data, [], fn trace, data_acc ->
        new_data =
          Enum.reduce(trace, %{}, fn {key, value}, acc ->
            acc = Map.put(acc, key, value)

            case value do
              # Plotly path and parameter
              %{"path" => _path, "parameter" => _parameter} ->
                Map.put(acc, key, process_plot_data(raw_data, value))

              # Standard plotly specifier
              _ ->
                Map.put(acc, key, value)
            end
          end)

        [new_data | data_acc]
      end)

    data = Enum.reverse(data)
    Map.put(plot_map, :data, data)
  end

  def get_trace_updates(%{plotly: nil} = plot_map, value, timestamp, parameter) do
    trace_index =
      Enum.find_index(plot_map.data, fn trace ->
        trace[:name] == parameter
      end) || 0

    # Format data for the extend-traces event
    # The event expects arrays of arrays (one per trace)
    %{
      # Add one timestamp to the specified trace
      x: [[timestamp]],
      # Add one value to the specified trace
      y: [[value]],
      traceIndices: [trace_index]
    }
  end

  # Get the updates for an incoming datareport with plotly specification
  def get_trace_updates(%{plotly: plotly} = _plot_map, value, timestamp, parameter) do
    raw_data = %{
      parameter => %{"timestamp" => [timestamp], "value" => [value]}
    }

    # Only collect traces that match the parameter
    matching_traces =
      plotly["data"]
      |> Enum.with_index()
      |> Enum.filter(fn {trace, _index} ->
        Map.get(trace, "parameter", "") == parameter
      end)


    # If no matching traces, return empty update
    update = if Enum.empty?(matching_traces) do
      %{x: [], y: [], traceIndices: []}
    else
      # Process only the matching traces
      Enum.reduce(matching_traces, %{x: [], y: [], traceIndices: []}, fn {trace, index}, acc ->
        {x, y, trace_indices} = get_extension(trace, index, raw_data)

        %{
          x: acc.x ++ [x],
          y: acc.y ++ [y],
          traceIndices: acc.traceIndices ++ trace_indices
        }
      end)
    end

    update
  end

  def get_extension(trace, trace_index, raw_data) do
    xdata =
      if Map.has_key?(trace, "x") do
        process_plot_data(raw_data, trace["x"])
      else
        [nil]
      end

    ydata =
      if Map.has_key?(trace, "y") do
        process_plot_data(raw_data, trace["y"])
      else
        [nil]
      end

    {xdata, ydata, [trace_index]}
  end

  def plottable?(%SecopService.Sec_Nodes.Parameter{} = parameter) do
    has_plotly_property = Map.has_key?(parameter.custom_properties || %{}, "_plotly")

    case parameter.datainfo["type"] do
      numeric when numeric in ["double", "int", "scaled"] -> true
      # TODO
      "bool" -> has_plotly_property
      # TODO
      "enum" -> has_plotly_property
      # TODO
      "array" -> has_plotly_property
      _ -> has_plotly_property
    end
  end

  def plottable?(%SecopService.Sec_Nodes.Module{} = module) do
    value_param = Enum.find(module.parameters, fn param -> param.name == "value" end)

    case value_param do
      nil -> false
      param -> plottable?(param) or Map.has_key?(module.custom_properties, "_plotly")
    end
  end

  def get_parameter(secop_obj) do
    case secop_obj do
      %SecopService.Sec_Nodes.Parameter{} = param ->
        param

      %SecopService.Sec_Nodes.Module{} = module ->
        Enum.find(module.parameters, fn param -> param.name == "value" end)
    end
  end

  defp get_unit(plot_map, parameter) do
    unit =
      if Map.has_key?(parameter.datainfo, "unit") do
        parameter.datainfo["unit"]
      else
        nil
      end

    Map.put(plot_map, :unit, unit)
  end

  defp plot_available(plot_map, plot_data) do
    plot_available =
      if length(plot_data) > 1 do
        true
      else
        false
      end

    Map.put(plot_map, :plot_available, plot_available)
  end

  defp set_chart_id(plot_map, chart_id) do
    Map.put(plot_map, :chart_id, chart_id)
  end

  def module_plot(module) do
    plotmap =
      case Util.get_highest_if_class(module.interface_classes) do
        :readable -> readable_plot(module)
        :drivable -> drivable_plot(module)
        :communicator -> not_plottable()
        :measurable -> not_plottable()
        _ -> not_plottable()
      end

    plotmap
  end

  def init(secop_obj) do
    case secop_obj do
      %SecopService.Sec_Nodes.Parameter{} = param ->
        parameter_plot(param)

      %SecopService.Sec_Nodes.Module{} = module ->
        module_plot(module)
    end
  end

  #
  def drivable_plot(module) do
    plot_map = %{}

    value_param = Enum.find(module.parameters, fn param -> param.name == "value" end)
    target_param = Enum.find(module.parameters, fn param -> param.name == "target" end)

    if plottable?(value_param) or Map.has_key?(module.custom_properties, "_plotly") do
      plot_map =
        Map.put(plot_map, :plottable, true)
        |> get_unit(value_param)
        |> Map.put(:plotly, Map.get(module.custom_properties, "_plotly", nil))

      {value_val, value_ts} =
        get_values_with_retry(value_param.id) |> Sec_Nodes.extract_value_timestamp_lists()

      {target_val, target_ts} =
        get_values_with_retry(target_param.id) |> Sec_Nodes.extract_value_timestamp_lists()

      plot_map = plot_available(plot_map, value_val)

      plot_map =
        plot_map
        |> get_data(value_ts, value_val, target_ts, target_val)
        |> get_layout()

      config =
        %{
          responsive: true,
          displayModeBar: false
        }

      Map.put(plot_map, :config, config)
    else
      not_plottable()
    end
  end

  def readable_plot(module) do
    plot_map = %{}

    value_param = Enum.find(module.parameters, fn param -> param.name == "value" end)

    plot_map =
      if plottable?(value_param) do
        plot_map =
          Map.put(plot_map, :plottable, true)
          |> get_unit(value_param)
          |> Map.put(:plotly, Map.get(module.custom_properties, "_plotly", nil))

        {value_val, value_ts} =
          get_values_with_retry(value_param.id) |> Sec_Nodes.extract_value_timestamp_lists()

        plot_map = plot_available(plot_map, value_val)

        plot_map =
          plot_map
          |> get_data(value_ts, value_val)
          |> get_layout()

        config =
          %{
            responsive: true,
            displayModeBar: false
          }

        Map.put(plot_map, :config, config)
      else
        not_plottable()
      end

    plot_map
  end

  def parameter_plot(parameter) do
    plot_map = %{}

    plot_map =
      if plottable?(parameter) do
        {value_val, value_ts} =
          get_values_with_retry(parameter.id) |> Sec_Nodes.extract_value_timestamp_lists()

        plot_map =
          Map.put(plot_map, :plottable, true)
          |> get_unit(parameter)
          |> Map.put(:plotly, Map.get(parameter.custom_properties, "_plotly", nil))
          |> set_chart_id(parameter.chart_id)

        plot_map = plot_available(plot_map, value_val)

        plot_map =
          plot_map
          |> get_data(value_ts, value_val)
          |> get_layout()

        config =
          %{
            responsive: true,
            displayModeBar: false
          }

        Map.put(plot_map, :config, config)
      else
        not_plottable()
      end

    plot_map
  end

  def no_plot_available() do
    %{plottable: true, plot_available: false}
  end

  def not_plottable() do
    %{plottable: false, plot_available: false, topics: []}
  end
end
