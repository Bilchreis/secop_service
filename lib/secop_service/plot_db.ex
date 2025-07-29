defmodule SecopService.PlotDB do
  alias SecopService.Util
  alias SecopService.Sec_Nodes

  @layout


  def get_layout(plot_map) do
    %{
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
          x: 0.28 ,
          xanchor: "left",
          y: 0.99,
          yanchor: "bottom",
          bgcolor: "rgba(200,200,200,1)",  # Transparent background
          font: %{size: 11}
        }
      ]



    }
  end

  def plottable?(parameter) do
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

    if plottable?(value_param) do
      plot_map =
        Map.put(plot_map, :plottable, true)
        |> get_unit(value_param)

      {value_val, value_ts} =
        Sec_Nodes.get_values(value_param.id) |> Sec_Nodes.extract_value_timestamp_lists()

      {target_val, target_ts} =
        Sec_Nodes.get_values(target_param.id) |> Sec_Nodes.extract_value_timestamp_lists()

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

      layout = get_layout(plot_map)

      config =
        %{
          responsive: true,
          displayModeBar: false
        }

      Map.put(plot_map, :data, data)
      |> Map.put(:layout, layout)
      |> Map.put(:config, config)
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

        {value_val, value_ts} =
          Sec_Nodes.get_values(value_param.id) |> Sec_Nodes.extract_value_timestamp_lists()

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

        layout = get_layout(plot_map)

        config =
          %{
            responsive: true,
            displayModeBar: false
          }

        Map.put(plot_map, :data, data)
        |> Map.put(:layout, layout)
        |> Map.put(:config, config)
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
          Sec_Nodes.get_values(parameter.id) |> Sec_Nodes.extract_value_timestamp_lists()

        plot_map =
          Map.put(plot_map, :plottable, true)
          |> get_unit(parameter)
          |> set_chart_id(parameter.chart_id)

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

        layout = get_layout(plot_map)

        config =
          %{
            responsive: true,
            displayModeBar: false
          }

        Map.put(plot_map, :data, data)
        |> Map.put(:layout, layout)
        |> Map.put(:config, config)
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
