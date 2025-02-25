defmodule SecopServiceWeb.DashboardLive.Plot do
  alias Explorer.DataFrame
  alias GGity.Plot

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

    Map.put(plot_map, :plottable, plottable)
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

    {value_val, value_ts} = module.parameters.value.plot_data
    {target_val, target_ts} = module.parameters.target.plot_data

    {df, plot_available} =
      if length(value_val) <= 1 do
        {nil, false}
      else
        dataframe =
          DataFrame.new(%{
            timestamp: value_ts ++ target_ts,
            value: value_val ++ target_val,
            variable:
              Enum.map(value_val, fn _val -> "value" end) ++
                Enum.map(target_val, fn _val -> "target" end)
          })

        {dataframe, true}
      end

    plot_map =
      line_plot(plot_map, df)
      |> Map.put(:plot_available, plot_available)

    Map.put(module, :plot, plot_map)
  end

  def readable_plot(module) do
    value_param = module.parameters.value

    plot_map = %{}

    plot_map =
      is_plottable(plot_map, value_param)
      |> get_unit(value_param)

    {value_val, value_ts} = module.parameters.value.plot_data

    {df, plot_available} =
      if length(value_val) <= 1 do
        {nil, false}
      else
        dataframe =
          DataFrame.new(%{
            timestamp: value_ts,
            value: value_val,
            variable: Enum.map(value_val, fn _val -> "value" end)
          })

        {dataframe, true}
      end

    plot_map =
      line_plot(plot_map, df)
      |> Map.put(:plot_available, plot_available)

    Map.put(module, :plot, plot_map)
  end

  def parameter_plot(parameter) do
    plot_map = %{}

    plot_map =
      is_plottable(plot_map, parameter)
      |> get_unit(parameter)

    {value_val, value_ts} = parameter.plot_data

    {df, plot_available} =
      if length(value_val) <= 1 do
        {nil, false}
      else
        dataframe =
          DataFrame.new(%{
            timestamp: value_ts,
            value: value_val,
            variable: Enum.map(value_val, fn _val -> "value" end)
          })

        {dataframe, true}
      end

    plot_map =
      line_plot(plot_map, df)
      |> Map.put(:plot_available, plot_available)

    Map.put(parameter, :plot, plot_map)
  end

  def line_plot(plot_map, dataframe) do
    plot =
      if dataframe do
        raw =
          Plot.new(dataframe, %{x: :timestamp, y: :value, color: "variable"}, aspect_ratio: 2.5)
          |> Plot.geom_line()
          |> Plot.labs(x: "time in s", y: plot_map.unit)
          |> Plot.theme(
            text: nil,
            axis_line: nil,
            axis_line_x: nil,
            axis_line_y: nil,
            axis_text: nil,
            axis_ticks: nil,
            axis_line_x: nil,
            axis_line_y: nil,
            axis_title: nil,
            axis_title_x: nil,
            axis_title_y: nil,
            panel_background: nil,
            legend_title: nil,
            legend_text: nil,
            panel_border: nil,
            panel_grid: nil,
            panel_grid_major: nil,
            panel_grid_minor: nil,
            plot_title: nil,
            plot_background: nil
          )
          |> Plot.plot()

        {:safe, raw}
      else
        nil
      end

    Map.put(plot_map, :svg, plot)
  end

  def no_plot_available(module) do
    Map.put(module, :plot, %{plottable: true, svg: nil, unit: nil, plot_available: false})
  end
  def not_plottable(module) do
    Map.put(module, :plot, %{plottable: false, svg: nil, unit: nil, plot_available: false})
  end

end
