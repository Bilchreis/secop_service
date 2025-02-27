defmodule SecopServiceWeb.DashboardLive.Plot do



  defp get_highest_if_class(module) do
    # TODO Measurable
    ifclasses = module.properties.interface_classes

    cond do
      Enum.member?(ifclasses, "Drivable") -> :drivable
      Enum.member?(ifclasses, "Readable") -> :readable
      Enum.member?(ifclasses, "Communicator") -> :communicator
      true -> nil
    end
  end

  defp is_plottable(plot_map, parameter) do
    plottable =
      case parameter.datainfo.type do
        numeric when numeric in ["double", "int", "scaled"] -> true
        # TODO
        "bool" -> false
        # TODO
        "enum" -> false
        # TODO
        "array" -> false
        _ -> false
      end

    Map.put(plot_map,:plottable, plottable)
  end

  defp get_unit(plot_map, parameter) do
    unit =
      if Map.has_key?(parameter.datainfo, :unit) do
        parameter.datainfo.unit
      else
        nil
      end

    Map.put(plot_map, :unit, unit)
  end

  defp plot_available(plot_map, plot_data) do
    plot_available = if length(plot_data) > 1 do
      true
    else
      false
    end
    Map.put(plot_map, :plot_available, plot_available)
  end

  defp set_chart_id(plot_map, chart_id) do
    Map.put(plot_map, :chart_id, chart_id)
  end

  # Helper function to convert Unix timestamps to ISO format for Plotly
  defp format_timestamps(timestamps) do

    to_milliseconds(timestamps)
  end

  defp to_milliseconds(timestamps) do
    Enum.map(timestamps, fn ts -> ts * 1000 end)
  end

  def module_plot(module) do
    updated_module =
      case get_highest_if_class(module) do
        :readable -> readable_plot(module)
        :drivable -> drivable_plot(module)
        :communicator -> not_plottable(module)
        _ -> not_plottable(module)
      end

    updated_module
  end


  def drivable_plot(module) do
    value_param = module.parameters.value

    plot_map = %{}

    plot_map =
      is_plottable(plot_map, value_param)
      |> get_unit(value_param)
      |> set_chart_id(module.chart_id)


    {value_val, value_ts} = module.parameters.value.plot_data
    {target_val, target_ts} = module.parameters.target.plot_data

    # Convert timestamps to ISO format
    formatted_value_ts = format_timestamps(value_ts)
    formatted_target_ts = format_timestamps(target_ts)

    plot_map = plot_available(plot_map, value_val)

    plot_data =
      {
        [
          %{
            x: formatted_value_ts,
            y: value_val,
            type: "scatter",
            mode: "lines",
            name: "value"
          },
          %{
            x: formatted_target_ts,
            y: target_val,
            type: "scatter",
            mode: "lines",
            name: "target"
          }
        ],
        %{
          xaxis: %{ title: %{ text: "Time" }, type: "date" },
          yaxis: %{ title: %{ text: "#{plot_map.unit}" } },
          margin: %{t: 30, b: 50, l: 50, r: 20},
          paper_bgcolor: "rgba(0,0,0,0", #background color of the chart container space,
          plot_bgcolor: "rgba(0,0,0,0)", ##background color of plot area
        },
        %{responsive: true}
      }

    plot_map = Map.put(plot_map, :plotly, plot_data)


    Map.put(module, :plot, plot_map)

  end

  def readable_plot(module) do
    value_param = module.parameters.value

    plot_map = %{}

    plot_map =
      is_plottable(plot_map, value_param)
      |> get_unit(value_param)
      |> set_chart_id(module.chart_id)


    {value_val, value_ts} = module.parameters.value.plot_data

    # Convert timestamps to ISO format
    formatted_value_ts = format_timestamps(value_ts)

    plot_map = plot_available(plot_map, value_val)

    plot_data =
      {
        [
          %{
            x: formatted_value_ts,
            y: value_val,
            type: "scatter",
            mode: "lines",
            name: "value"
          }
        ],
        %{
          xaxis: %{ title: %{ text: "Time" }, type: "date" },
          yaxis: %{title: "#{plot_map.unit}"},
          margin: %{t: 30, b: 40, l: 50, r: 20},
          paper_bgcolor: "rgba(0,0,0,0", #background color of the chart container space,
          plot_bgcolor: "rgba(0,0,0,0)", ##background color of plot area
        },
        %{responsive: true}
      }

    plot_map = Map.put(plot_map, :plotly, plot_data)

    Map.put(module, :plot, plot_map)
  end

  def parameter_plot(parameter) do
    plot_map = %{}

    plot_map =
      is_plottable(plot_map, parameter)
      |> get_unit(parameter)
      |> set_chart_id(parameter.chart_id)

    {value_val, value_ts} = parameter.plot_data

    # Convert timestamps to ISO format
    formatted_value_ts = format_timestamps(value_ts)

    plot_map = plot_available(plot_map, value_val)

    plot_data =
      {
        [
          %{
            x: formatted_value_ts,
            y: value_val,
            type: "scatter",
            mode: "lines",
            name: "value"
          }
        ],
        %{
          xaxis: %{title: "Time", type: "date"},
          yaxis: %{title: "#{plot_map.unit}"},
          margin: %{t: 30, b: 40, l: 50, r: 20},
          paper_bgcolor: "rgba(0,0,0,0", #background color of the chart container space,
          plot_bgcolor: "rgba(0,0,0,0)", ##background color of plot area
        },
        %{responsive: true}
      }

    plot_map = Map.put(plot_map, :plotly, plot_data)

    Map.put(parameter, :plot, plot_map)
  end


  def no_plot_available(module) do
    Map.put(module, :plot, %{plottable: true, plot_available: false})
  end
  def not_plottable(module) do
    Map.put(module, :plot, %{plottable: false, plot_available: false})
  end

end
