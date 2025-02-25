defmodule SECoPComponents do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias Jason

  alias Explorer.DataFrame
  alias GGity.Plot

  import SecopServiceWeb.CoreComponents, only: [icon: 1]

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
    <div class=" flex justify-between items-center py-2  ">
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
      <.accordion id={@mod_name} class="mb-2 bg-white dark:bg-gray-700 rounded-lg  ">
        <:trigger class="p-4 pr-10 text-lg">
          <h3 class="text-lg text-left font-bold text-gray-900 dark:text-white">
            {@mod_name} :
            <span class=" dark:text-gray-400 text-medium">
              {Enum.at(@module.properties.interface_classes, 0)}
            </span>
          </h3>
          <div>
            <div class="text-left dark:text-gray-400">
              {@module.properties.description}
            </div>
          </div>
        </:trigger>
        <:panel class="p-4 ">
          <%= for {prop_name, prop_value} <- @module.properties, prop_name != :description do %>
            <div>
              <div class="mt-2 dark:bg-gray-800  text-gray-300 text-left  py-2 px-4 rounded">
                <span class=" font-bold  text-black dark:text-white ">{prop_name}:</span> <br />
                {prop_value}
              </div>
            </div>
          <% end %>
        </:panel>
      </.accordion>
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

  def line_plot_ggity(assigns) do
    plot =
      if assigns.plot_data != [] do
        curr_time = System.os_time(:millisecond) * 0.001

        plot_data =
          Enum.map(assigns.plot_data, fn {timestamp, value} -> {timestamp - curr_time, value} end)
          |> Enum.reject(fn {timestamp, _value} -> timestamp < -900 end)

        df =
          DataFrame.new(%{
            timestamp: Enum.map(plot_data, fn {ts, _val} -> ts end),
            value: Enum.map(plot_data, fn {_ts, val} -> val end)
          })

        raw =
          Plot.new(df, %{x: :timestamp, y: :value})
          |> Plot.geom_line()
          |> Plot.plot()

        {:safe, raw}
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
      numeric when numeric in ["double", "int", "scaled"] -> line_plot_ggity(assigns)
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
    # TODO Measurable
    ifclasses = module.properties.interface_classes

    cond do
      Enum.member?(ifclasses, "Drivable") -> :drivable
      Enum.member?(ifclasses, "Readable") -> :readable
      Enum.member?(ifclasses, "Communicator") -> :communicator
      true -> nil
    end
  end

  attr :module_name, :string, required: true
  attr :module, :map, required: true

  def module_plot(assigns) do
    ~H"""
    <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-2">{@module_name} : </h3>
    <div>

      <.general_plot
      plottable = {@module.plot.plottable}
      svg = {@module.plot.svg}
      unit = {@module.plot.unit}
      plot_available = {@module.plot.plot_available}
      />
    </div>
    """
  end


  attr :plottable, :boolean, required: true
  attr :svg,  :any, required: true
  attr :unit, :string, required: false
  attr :plot_available, :boolean, default: false
  def general_plot(assigns) do
    ~H"""
    <%= if @plottable do %>
      <%= if @plot_available do %>
        <div>
            {@svg}
        </div>
      <% else %>
        <div class="  animate-pulse  flex items-center justify-center h-full text-center">
          Waiting for plottable Data
        </div>
      <% end %>
    <% else %>
      Data not Plottable
    <% end %>
    """
  end

  attr :module_name, :string, required: true
  attr :module, :map, required: true

  def readable_plot(assigns) do
    datainfo = assigns.module.parameters.value.datainfo

    plottable =
      case datainfo.type do
        numeric when numeric in ["double", "int", "scaled"] -> true
        # TODO
        "bool" -> false
        # TODO
        "enum" -> false
        # TODO
        "array" -> false
        _ -> false
      end

    unit =
      if Map.has_key?(datainfo, :unit) do
        datainfo.unit
      else
        nil
      end

    assigns = assign(assigns, :plottable, plottable)

    {value, timestamp} = assigns.module.parameters.value.plot_data

    df =
      if value == [] do
        nil
      else
        DataFrame.new(%{
          timestamp: timestamp,
          value: value,
          variable: Enum.map(value, fn _val -> "value" end)
        })
      end

    assigns =
      assign(assigns, :dataframe, df)
      |> assign(:unit, unit)
      |> assign(:plottable, plottable)

    ~H"""
    <h3 class="text-lg mt-4 font-bold text-gray-900 dark:text-white mb-2">
      {@module_name} : [value]
    </h3>
    <.line_plot dataframe={@dataframe} plottable={@plottable} unit={@unit} />
    """
  end

  attr :unit, :string, default: nil
  attr :dataframe, :map, required: true
  attr :plottable, :boolean, required: true

  def line_plot(assigns) do
    dataframe = assigns.dataframe

    plot =
      if dataframe do
        raw =
          Plot.new(dataframe, %{x: :timestamp, y: :value, color: "variable"}, aspect_ratio: 2.5)
          |> Plot.geom_line()
          |> Plot.labs(x: "time in s", y: assigns.unit)
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
        "Waiting for Data"
      end

    assigns = assign(assigns, :plot, plot)

    ~H"""
    <%= if @plottable  do %>
      <%= if @dataframe == nil do %>
        <div class="  animate-pulse  flex items-center justify-center h-full text-center">
          {@plot}
        </div>
      <% else %>
        <div>
          {@plot}
        </div>
      <% end %>
    <% else %>
      <.no_plot_available />
    <% end %>
    """
  end

  attr :module_name, :string, required: true
  attr :module, :map, required: true

  def drivable_plot(assigns) do
    datainfo = assigns.module.parameters.value.datainfo

    plottable =
      case datainfo.type do
        numeric when numeric in ["double", "int", "scaled"] -> true
        # TODO
        "bool" -> false
        # TODO
        "enum" -> false
        # TODO
        "array" -> false
        _ -> false
      end

    unit =
      if Map.has_key?(datainfo, :unit) do
        datainfo.unit
      else
        nil
      end

    assigns = assign(assigns, :plottable, plottable)

    {value_val, value_ts} = assigns.module.parameters.value.plot_data
    {target_val, target_ts} = assigns.module.parameters.target.plot_data

    df =
      if value_val == [] do
        nil
      else
        DataFrame.new(%{
          timestamp: value_ts ++ target_ts,
          value: value_val ++ target_val,
          variable:
            Enum.map(value_val, fn _val -> "value" end) ++
              Enum.map(target_val, fn _val -> "target" end)
        })
      end

    assigns =
      assign(assigns, :dataframe, df)
      |> assign(:unit, unit)
      |> assign(:plottable, plottable)

    ~H"""
    <h3 class="text-lg mt-4 font-bold text-gray-900 dark:text-white mb-2">
      {@module_name} : [value, target]
    </h3>
    <.line_plot dataframe={@dataframe} plottable={@plottable} unit={@unit} />
    """
  end

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

  attr :class, :any, doc: "Extend existing component styles"
  attr :controlled, :boolean, default: false
  attr :id, :string, required: true
  attr :rest, :global

  slot :trigger, validate_attrs: false
  slot :panel, validate_attrs: false

  @spec accordion(Socket.assigns()) :: Rendered.t()
  def accordion(assigns) do
    ~H"""
    <div class={["accordion", assigns[:class]]} id={@id} {@rest}>
      <%= for {{trigger, panel}, idx} <- @trigger |> Enum.zip(@panel) |> Enum.with_index() do %>
        <h3>
          <button
            aria-controls={panel_id(@id, idx)}
            aria-expanded={to_string(panel[:default_expanded] == true)}
            class={[
              "accordion-trigger relative w-full [&_.accordion-trigger-icon]:aria-expanded:rotate-180",
              trigger[:class]
            ]}
            id={trigger_id(@id, idx)}
            phx-click={handle_click(assigns, idx)}
            type="button"
            {assigns_to_attributes(trigger, [:class, :icon_name])}
          >
            {render_slot(trigger)}
            <.icon
              class="accordion-trigger-icon h-5 w-5 absolute right-4 transition-all ease-in-out duration-300 top-1/2 -translate-y-1/2"
              name={trigger[:icon_name] || "hero-chevron-down"}
            />
          </button>
        </h3>
        <div
          class="accordion-panel grid grid-rows-[0fr] data-[expanded]:grid-rows-[1fr] transition-all transform ease-in duration-200"
          data-expanded={panel[:default_expanded]}
          id={panel_id(@id, idx)}
          role="region"
        >
          <div class="overflow-hidden">
            <div
              class={["accordion-panel-content", panel[:class]]}
              {assigns_to_attributes(panel, [:class, :default_expanded ])}
            >
              {render_slot(panel)}
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp trigger_id(id, idx), do: "#{id}_trigger#{idx}"
  defp panel_id(id, idx), do: "#{id}_panel#{idx}"

  defp handle_click(%{controlled: controlled, id: id}, idx) do
    op =
      {"aria-expanded", "true", "false"}
      |> JS.toggle_attribute(to: "##{trigger_id(id, idx)}")
      |> JS.toggle_attribute({"data-expanded", ""}, to: "##{panel_id(id, idx)}")

    if controlled do
      op
      |> JS.set_attribute({"aria-expanded", "false"},
        to: "##{id} .accordion-trigger:not(##{trigger_id(id, idx)})"
      )
      |> JS.remove_attribute("data-expanded",
        to: "##{id} .accordion-panel:not(##{panel_id(id, idx)})"
      )
    else
      op
    end
  end
end
