defmodule SecopService.PlotDB do
  alias SecopService.Sec_Nodes.SEC_Node
  alias SecopService.Sec_Nodes.{Module, Parameter, Command, ParameterValue}
  alias SecopService.Util
  alias SecopService.Sec_Nodes



  defp is_plottable(plot_map, parameter) do
    plottable =
      case parameter.datainfo["type"] do
        numeric when numeric in ["double", "int", "scaled"] -> true
        # TODO
        "bool" -> false
        # TODO
        "enum" -> false
        # TODO
        "array" -> false
        _ -> false
      end

    Map.put(plot_map, :plottable, plottable)
  end

  defp get_unit(plot_map, parameter) do
    IO.inspect(parameter, label: "Parameter")

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

  # Helper function to convert Unix timestamps to ISO format for Plotly
  defp format_timestamps(timestamps) do
    to_milliseconds(timestamps)
  end

  defp to_milliseconds(timestamps) do
    Enum.map(timestamps, fn ts -> ts * 1000 end)
  end

  def module_plot(module) do
    plotmap = case Util.get_highest_if_class(module.interface_classes) do
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



  def drivable_plot(module) do
    value_param = Enum.find(module.parameters, fn param -> param.name == "value" end)
    target_param = Enum.find(module.parameters, fn param -> param.name == "target" end)

    plot_map = %{}

    plot_map =
      is_plottable(plot_map, value_param)
      |> get_unit(value_param)

    IO.inspect(plot_map, label: "Plot Map")


    {value_val , value_ts} = Sec_Nodes.get_values(value_param.id) |> Sec_Nodes.extract_value_timestamp_lists()
    {target_val, target_ts} = Sec_Nodes.get_values(target_param.id) |> Sec_Nodes.extract_value_timestamp_lists()

    plot_map = plot_available(plot_map, value_val)

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

    layout = %{
      xaxis: %{title: %{text: "Time"}, type: "date"},
      yaxis: %{title: %{text: "#{plot_map.unit}"}},
      margin: %{t: 30, b: 50, l: 50, r: 20},
      # background color of the chart container space,
      paper_bgcolor: "rgba(0,0,0,0",
      ## background color of plot area
      plot_bgcolor: "rgba(0,0,0,0)"
    }

    config =
      %{
        responsive: true,
        displayModeBar: false
      }

    Map.put(plot_map, :data, data)
    |> Map.put(:layout, layout)
    |> Map.put(:config, config)


  end


  def readable_plot(module) do
    value_param = Enum.find(module.parameters, fn param -> param.name == "value" end)

    plot_map = %{}

    plot_map =
      is_plottable(plot_map, value_param)
      |> get_unit(value_param)


    {value_val , value_ts} = Sec_Nodes.get_values(value_param.id) |> Sec_Nodes.extract_value_timestamp_lists()


    plot_map = plot_available(plot_map, value_val)

    data = [
      %{
        x: value_ts,
        y: value_val,
        type: "scatter",
        mode: "lines",
        name: "value"
      }
    ]

    layout = %{
      xaxis: %{title: %{text: "Time"}, type: "date"},
      yaxis: %{title: %{text: "#{plot_map.unit}"}},
      margin: %{t: 30, b: 50, l: 50, r: 20},
      # background color of the chart container space,
      paper_bgcolor: "rgba(0,0,0,0",
      ## background color of plot area
      plot_bgcolor: "rgba(0,0,0,0)"
    }

    config =
      %{
        responsive: true,
        displayModeBar: false
      }

    Map.put(plot_map, :data, data)
    |> Map.put(:layout, layout)
    |> Map.put(:config, config)

  end

  def parameter_plot(parameter) do
    {:ok, {value_val, value_ts}} = PlotPublisher.get_data(parameter.parameter_id)

    plot_map = %{}

    plot_map = Map.put(plot_map, :topics, [parameter.parameter_topic])

    plot_map =
      is_plottable(plot_map, parameter)
      |> get_unit(parameter)
      |> set_chart_id(parameter.chart_id)



    # Convert timestamps to ISO format
    formatted_value_ts = format_timestamps(value_ts)

    plot_map = plot_available(plot_map, value_val)

    data = [
      %{
        x: formatted_value_ts,
        y: value_val,
        type: "scatter",
        mode: "lines",
        name: "value"
      }
    ]

    layout = %{
      xaxis: %{title: %{text: "Time"}, type: "date"},
      yaxis: %{title: %{text: "#{plot_map.unit}"}},
      margin: %{t: 30, b: 50, l: 50, r: 20},
      # background color of the chart container space,
      paper_bgcolor: "rgba(0,0,0,0",
      ## background color of plot area
      plot_bgcolor: "rgba(0,0,0,0)"
    }

    config =
      %{
        responsive: true,
        displayModeBar: false
      }

    Map.put(plot_map, :data, data)
    |> Map.put(:layout, layout)
    |> Map.put(:config, config)
  end



  def parameter_plot(parameter) do
    {:ok, {value_val, value_ts}} = PlotPublisher.get_data(parameter.parameter_id)

    plot_map = %{}

    plot_map = Map.put(plot_map, :topics, [parameter.parameter_topic])

    plot_map =
      is_plottable(plot_map, parameter)
      |> get_unit(parameter)
      |> set_chart_id(parameter.chart_id)

    # Convert timestamps to ISO format
    formatted_value_ts = format_timestamps(value_ts)

    plot_map = plot_available(plot_map, value_val)

    data = [
      %{
        x: formatted_value_ts,
        y: value_val,
        type: "scatter",
        mode: "lines",
        name: "value"
      }
    ]

    layout = %{
      xaxis: %{title: %{text: "Time"}, type: "date"},
      yaxis: %{title: %{text: "#{plot_map.unit}"}},
      margin: %{t: 30, b: 50, l: 50, r: 20},
      # background color of the chart container space,
      paper_bgcolor: "rgba(0,0,0,0",
      ## background color of plot area
      plot_bgcolor: "rgba(0,0,0,0)"
    }

    config =
      %{
        responsive: true,
        displayModeBar: false
      }

    Map.put(plot_map, :data, data)
    |> Map.put(:layout, layout)
    |> Map.put(:config, config)
  end

  def no_plot_available() do
    %{plottable: true, plot_available: false}
  end

  def not_plottable() do
    %{plottable: false, plot_available: false, topics: []}
  end
end
