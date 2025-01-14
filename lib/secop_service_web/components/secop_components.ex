defmodule SECoPComponents do
  use Phoenix.Component
  alias Jason

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
    <div class="flex justify-between items-center py-2  ">
      PLACEHOLDER
    </div>
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

  attr :module_name, :string, required: true
  attr :status, :string, required: true
  attr :current, :boolean, default: false
  attr :node_status, :atom, required: true

  def module_button(assigns) do
    assigns =
      case assigns.node_status do
        :initialized ->
          assigns

        _ ->
          status = assigns.status
          status = %{status | status_color: "gray-500"}

          assign(assigns, :status, status)
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
        <span class={[
          @status.status_color,
          "inline-block w-6 h-6 mr-2 rounded-full border-4 border-gray-600"
        ]}>
        </span>
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
