defmodule SECoPComponents do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias Jason
  alias SecopService.Util
  import SecopServiceWeb.CoreComponents

  attr :equipment_id, :string, required: true
  attr :pubsub_topic, :string, required: true
  attr :uuid, :string, required: true
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
      phx-value-pstopic={@pubsub_topic}
      class={[
        @button_col,
        @border_col,
        "border-4 text-white text-left font-bold py-2 px-4 rounded"
      ]}
    >
      <div class="text-xl">{Util.display_name(@equipment_id)}</div>
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

  def dash_parameter(assigns) do
    assigns =
      assign(assigns, parse_param_value(assigns[:parameter]))
      |> assign(:unit, Map.get(assigns.parameter.datainfo, :unit))

    ~H"""
    <div class=" flex justify-between items-start   ">
      <div class="mt-4 block w-full rounded-lg text-white text-lg ">
        {@parameter_name}:
      </div>
    </div>
    <div class="flex justify-between items-start  ">
      <div class="mt-4 block w-full rounded-lg text-white text-lg ">
        {@string_value} {@unit}
      </div>
    </div>
    <%= if @parameter.readonly do %>
      <div class="flex justify-between items-start "></div>
    <% else %>
      <div class="flex justify-between items-start">
        <.form
          for={@parameter.set_form}
          phx-submit="set_parameter"
          phx-change="validate_parameter"
          class="flex space-x-2"
        >
          <input
            type="hidden"
            name="port"
            value={Phoenix.HTML.Form.input_value(@parameter.set_form, :port)}
          />
          <input
            type="hidden"
            name="host"
            value={Phoenix.HTML.Form.input_value(@parameter.set_form, :host)}
          />
          <input
            type="hidden"
            name="module"
            value={Phoenix.HTML.Form.input_value(@parameter.set_form, :module)}
          />
          <input type="hidden" name="parameter" value={@parameter_name} />
          <.input
            name="value"
            type="text"
            field={@parameter.set_form[:value]}
            placeholder="new value"
            phx-debounce="500"
            id={"form:" <> @parameter.parameter_id }
          />
          <button
            type="submit"
            class="mt-2 max-h-11 phx-submit-loading:opacity-75 rounded-lg dark:bg-gray-500 bg-gray-400 hover:bg-gray-600 dark:hover:bg-gray-700   px-3 text-sm font-bold leading-6 text-white active:text-white/80"
          >
            Set
          </button>
        </.form>
      </div>
    <% end %>
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
      "bg-gray-50  p-5 bg-gray-50 text-medium text-gray-500 dark:text-gray-400 dark:bg-gray-900 rounded-lg w-full mb-4"
    ]}>
      <.accordion
        id={@mod_name}
        class="mb-2 bg-white dark:bg-gray-700 dark:hover:bg-gray-600 rounded-lg  "
      >
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
      <div class="grid grid-cols-3 gap-7 pt-6 content-start">
        <%= for {parameter_name, parameter} <- @module.parameters do %>
          <.dash_parameter parameter_name={parameter_name} parameter={parameter} />
        <% end %>
      </div>
    </div>
    """
  end

  attr :parameter, :string, required: true
  attr :module, :string, required: true
  attr :parameter_map, :map, required: true

  def hist_widget(assigns) do
    ~H"""
    <div class=" h-full pt-5 "></div>
    """
  end

  attr :module_name, :string, required: true
  attr :node_status, :atom, required: true
  attr :status_value, :map, required: true


  def module_indicator_status(assigns) do


    ~H"""
    <div class={[
      "min-w-full text-white text-left font-bold py-2 px-4 rounded",
      case @node_status do
        :connected -> "bg-orange-500"
        :disconnected -> "bg-red-500"
        :initialized -> "bg-zinc-400 dark:bg-zinc-500"
        _ -> "bg-red-500"  # default fallback
      end
    ]}>
     <div class="flex items-center">
        <div>
          <span class={[
            (if @status_value.data_report != nil, do: @status_value.stat_color, else: "bg-gray-500"),
            "inline-block w-6 h-6 mr-2 rounded-full border-4 border-gray-600"
          ]}>
          </span>
        </div>
        <div>
          <div class="text-xl">{Util.display_name(@module_name)}</div>
            <%= if @status_value.data_report != nil do %>
              <div class="text-sm text-white-400 opacity-60">
                {@status_value.stat_code} : {@status_value.stat_string}
              </div>
            <% else %>
              <div class="text-sm text-white-400 opacity-60">
                waiting for data...
              </div>
            <% end %>
        </div>
      </div>
    </div>
    """
  end


  attr :module_name, :string, required: true
  attr :node_status, :atom, required: true

  def module_indicator(assigns) do

    ~H"""
    <div class={[
      "min-w-full text-white text-left font-bold py-2 px-4 rounded",
      case @node_status do
        :connected -> "bg-orange-500"
        :disconnected -> "bg-red-500"
        :initialized -> "bg-zinc-500"
        _ -> "bg-red-500"  # default fallback
      end
    ]}>
     <div class="flex items-center">
        <div>
          <span class={[
            "opacity-0",
            "bg-gray-500",
            "inline-block w-6 h-6 mr-2 rounded-full border-4 border-gray-600"
          ]}>
          </span>
        </div>
        <div>
          <div class="text-xl">{Util.display_name(@module_name)}</div>
            <div class="text-sm text-white-400 opacity-0">
              placeholder
            </div>

        </div>
      </div>
    </div>
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

  def connect_node(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-xl  p-6">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-xl font-bold text-gray-900 dark:text-white">Connect to Node</h3>
      </div>

      <form phx-submit="connect-node">
        <div class="mb-4">
          <label for="host" class="block mb-2 text-sm font-medium text-gray-900 dark:text-white">
            Host
          </label>
          <input
            type="text"
            id="host"
            name="host"
            placeholder="localhost"
            required
            class="bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
          />
        </div>
        <div class="mb-4">
          <label for="port" class="block mb-2 text-sm font-medium text-gray-900 dark:text-white">
            Port
          </label>
          <input
            type="number"
            id="port"
            name="port"
            placeholder="8080"
            required
            min="1"
            max="65535"
            class="bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:text-white"
          />
        </div>
        <div class="flex justify-end">
          <button
            type="button"
            phx-click="close_connect_modal"
            class="mr-2 text-gray-500 bg-gray-200 hover:bg-gray-300 focus:outline-none rounded-lg border border-gray-200 text-sm font-medium px-5 py-2.5 dark:bg-gray-700 dark:text-gray-300 dark:border-gray-500 dark:hover:bg-gray-600"
          >
            Cancel
          </button>
          <button
            type="submit"
            class="text-white bg-purple-500 hover:bg-purple-700 focus:outline-none font-medium rounded-lg text-sm px-5 py-2.5 dark:bg-purple-600 dark:hover:bg-purple-700"
          >
            Connect
          </button>
        </div>
      </form>
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
