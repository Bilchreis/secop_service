defmodule SECoPComponents do
  use Phoenix.Component
  alias Jason
  alias Contex.{LinePlot, Dataset, Plot}

  attr :equipment_id, :string, required: true
  attr :pubsub_topic, :string, required: true
  attr :current, :boolean, default: false
  attr :state, :atom, required: true

  def node_button(assigns) do
    assigns = assign(assigns, :border_col, state_to_col(assigns.state))

    assigns =
      case assigns.current do
        true -> assign(assigns, :button_col, "bg-purple-500 hover:bg-purple-700")
        false -> assign(assigns, :button_col, "bg-zinc-500 hover:bg-zinc-700")
      end

    ~H"""
    <button
      phx-click="node-select"
      phx-value-pubsubtopic={@pubsub_topic}
      class={[
        @button_col,
        @border_col,
        "border-4 text-white text-left font-bold py-2 px-4 rounded"
      ]}
    >
      <div class="text-xl">{@equipment_id}</div>
      <div class="text-sm text-white-400 opacity-60">{@pubsub_topic}</div>
      <div>{@state}</div>
    </button>
    """
  end

  defp state_to_col(state) do
    col =
      case state do
        :connected -> "border-orange-500"
        :disconnected -> "border-red-500"
        :initialized -> "border-green-500"
        _ -> "border-gray-500"
      end

    col
  end

  attr :parameter, :string, required: true
  attr :parameter_name, :string, required: true

  def parameter(assigns) do
    assigns = assign(assigns, parse_param_value(assigns[:parameter]))

    ~H"""
    <div class="flex justify-between items-center py-2  ">
      {@parameter_name}:
    </div>
    <div class="flex justify-between items-center py-2  ">
      {@string_value}
    </div>
    <div class="flex justify-between items-center py-2  "></div>
    """
  end

  defp parse_param_value(parameter) do
    string_val =
      case parameter.value do
        nil -> %{string_value: "No value"}
        [value | _rest] -> %{string_value: Jason.encode!(value)}
      end

    string_val
  end

  attr :mod_name, :string, required: true
  attr :module, :map, required: true
  attr :state, :atom, required: true
  attr :box_color, :string, default: "bg-gray-50 dark:bg-gray-900"

  def module_box(assigns) do
    assigns =
      case assigns.state do
        :initialized -> assigns
        _ -> assign(assigns, :box_color, "border-4 border-red-500")
      end

    ~H"""
    <div class={[
      @box_color,
      "bg-gray-50 dark:bg-gray-900 p-5 bg-gray-50 text-medium text-gray-500 dark:text-gray-400 dark:bg-gray-900 rounded-lg w-full mb-4"
    ]}>
      <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-2">{@mod_name}</h3>
      <div class="grid grid-cols-3 gap-4 content-start">
        <%= for {parameter_name, parameter} <- @module.parameters do %>
          <.parameter parameter_name={parameter_name} parameter={parameter} />
        <% end %>
      </div>
    </div>
    """
  end

  attr :datainfo, :map, required: true
  attr :parameter, :string, required: true
  attr :module, :string, required: true
  attr :description, :string, required: true
  attr :plot_data, :map, default: []

  def line_plot(assigns) do
    plot =
      if assigns.plot_data != [] do
        unit = Map.get(assigns.datainfo, :unit)

        curr_time = System.os_time(:millisecond) * 0.001

        plot_data =
          Enum.map(assigns.plot_data, fn {timestamp, value} -> {timestamp - curr_time, value} end)
          |> Enum.reject(fn {timestamp, _value} -> timestamp < -900 end)

        ds = Dataset.new(plot_data, ["t", "value"])

        custom_x_scale =
          Contex.ContinuousLinearScale.new()
          |> Contex.ContinuousLinearScale.domain(-900, 0)
          |> Contex.ContinuousLinearScale.interval_count(18)

        datainfo = assigns.datainfo


        custom_y_scale =  if  Map.has_key?(datainfo,:min) and Map.has_key?(datainfo,:max) do


          Contex.ContinuousLinearScale.new() |> Contex.ContinuousLinearScale.domain(datainfo.min, datainfo.max)
        else
          nil
        end





        plot =
          Plot.new(ds, LinePlot, 600, 240, custom_x_scale: custom_x_scale, custom_y_scale: custom_y_scale)
          |> Plot.plot_options(%{legend_setting: :legend_right})
          |> Plot.axis_labels("t in s", unit)

        Plot.to_svg(plot)
      else
        "Waiting for Data"
      end

    assigns = assign(assigns, :plot, plot)

    ~H"""
    <%= if @plot_data == [] do %>
      <div class="  animate-pulse  flex items-center justify-center h-full text-center">
        {@plot}
      </div>
    <% else %>
      <div>
        <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-2">{@module} : {@parameter}</h3>
        {@plot}
      </div>
    <% end %>
    """
  end

  attr :datainfo, :map, required: true
  attr :parameter, :string, required: true
  attr :module, :string, required: true
  attr :description, :string, required: true
  attr :plot_data, :map, default: []

  def parameter_plot(assigns) do
    dtype = assigns.datainfo.type

    case dtype do
      numeric when numeric in ["double", "int", "scaled"] -> line_plot(assigns)
      # TODO
      "bool" -> no_plot_available(assigns)
      # TODO
      "enum" -> no_plot_available(assigns)
      # TODO
      "array" -> no_plot_available(assigns)
      _ -> no_plot_available(assigns)
    end
  end

  defp get_highest_if_class(module) do
    #TODO Measurable
    ifclasses = module.properties.interface_classes

    cond  do
      Enum.member?(ifclasses, "Drivable") -> :readable
      Enum.member?(ifclasses, "Readable") -> :drivable
      Enum.member?(ifclasses, "Communicator") -> :communicator
      true -> nil
    end


  end

  attr :module_name, :string, required: true
  attr :module, :map, required: true
  def module_plot(assigns) do

    IO.inspect(assigns)

    case get_highest_if_class(assigns.module) do
      :readable -> no_plot_available(assigns)
      :drivable -> no_plot_available(assigns)
      :communicator ->  no_plot_available(assigns)
      _ ->  no_plot_available(assigns)

    end

  end




  attr :datainfo, :map, required: true
  attr :parameter, :string, required: true
  attr :module, :string, required: true
  attr :description, :string, required: true
  attr :plot_data, :map, default: []

  def no_plot_available(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-full text-center">
      Data not Plottable
    </div>
    """
  end

  attr :parameter, :string, required: true
  attr :module, :string, required: true
  attr :parameter_map, :map, required: true

  def hist_widget(assigns) do
    ~H"""
    <div class=" h-full pt-5 ">
      <.parameter_plot
        datainfo={assigns.parameter_map.datainfo}
        parameter={assigns.parameter}
        module={assigns.module}
        description={assigns.parameter_map.description}
        plot_data={assigns.parameter_map.plot_data}
      />
    </div>
    """
  end

  attr :module_name, :string, required: true
  attr :module, :map, required: true
  attr :current, :boolean, default: false
  attr :node_status, :atom, required: true
  attr :hide_indicator, :string, default: ""

  def module_button(assigns) do
    assigns =
      if Map.has_key?(assigns.module.parameters, :status) do
        assigns = assign(assigns, :status, assigns.module.parameters.status)

        assigns =
          case assigns.node_status do
            :initialized ->
              assigns

            _ ->
              status = assigns.status
              status = %{status | status_color: "gray-500"}

              assign(assigns, :status, status)
          end

        assigns
      else
        status = %{status_color: "bg-gray-500", stat_code: 0, stat_string: "blah"}

        assign(assigns, :status, status)
        |> assign(:hide_indicator, "hidden")
      end

    ~H"""
    <button class={
      if @current do
        "min-w-full bg-purple-500 hover:bg-purple-700 text-white text-left font-bold py-2 px-4 rounded"
      else
        "min-w-full bg-zinc-500  hover:bg-zinc-700 text-white text-left font-bold py-2 px-4 rounded"
      end
    }>
      <div class="flex items-center">
        <div>
          <span class={[
            @hide_indicator,
            @status.status_color,
            "inline-block w-6 h-6 mr-2 rounded-full border-4 border-gray-600"
          ]}>
          </span>
        </div>
        <div>
          <div class="text-xl">{@module_name}</div>
          <div class="text-sm text-white-400 opacity-60">
            {@status.stat_code} : {@status.stat_string}
          </div>
        </div>
      </div>
    </button>
    """
  end
end
