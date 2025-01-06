defmodule SECoPComponents do
  use Phoenix.Component
  alias Jason


  attr :equipment_id, :string, required: true
  attr :pubsub_topic, :string, required: true
  attr :current, :boolean, default: false

  def node_button(assigns) do
    ~H"""
    <button phx-click="node-select" phx-value-pubsubtopic={@pubsub_topic} class={
      if @current do
        "bg-purple-500 hover:bg-purple-700  text-white text-left font-bold py-2 px-4 rounded"
      else
        "bg-zinc-500 hover:bg-sinz-700 text-white text-left font-bold py-2 px-4 rounded"
      end
    }>
      <div class="text-xl"><%= @equipment_id %></div>
      <div class="text-sm text-white-400 opacity-60"><%= @pubsub_topic %></div>
    </button>
    """
  end



  attr :parameter, :string, required: true
  attr :parameter_name, :string, required: true

  def parameter(assigns) do

    assigns = assign(assigns, parse_param_value(assigns[:parameter]))

    ~H"""
      <div class="flex justify-between items-center py-2  ">
        <%= @parameter_name %>:
      </div>
      <div class="flex justify-between items-center py-2  ">
        <%= @string_value %>
      </div>
      <div class="flex justify-between items-center py-2  ">
       PLACEHOLDER
      </div>

    """
  end

  defp parse_param_value(parameter) do

    string_val = case parameter.value do
      nil -> %{string_value: "No value"}
      [ value |_rest]  -> %{string_value: Jason.encode!(value)}
    end

    string_val
  end

  attr :module_name, :string, required: true
  attr :status, :string, required: true
  attr :current, :boolean, default: false

  def module_button(assigns) do


    assigns = assign(assigns, parse_status(assigns[:status]))

    #IO.inspect(assigns)
    ~H"""
    <button class={
      if @current do
        "min-w-full bg-purple-500 hover:bg-purple-700 text-white text-left font-bold py-2 px-4 rounded"
      else
        "min-w-full bg-zinc-500 hover:bg-zinc-700 text-white text-left font-bold py-2 px-4 rounded"
      end
    }>
      <div class="flex items-center">
        <span class={
          [
            @status_color,
            "inline-block w-6 h-6 mr-2 rounded-full border-4 border-gray-600"
            ]}>
        </span>
        <div>
          <div class="text-xl"><%= @module_name %></div>
          <div class="text-sm text-white-400 opacity-60"><%= @stat_code %> : <%= @stat_string %></div>
        </div>
      </div>
    </button>
    """
  end

  defp parse_status(status) do

      statmap =
        case status[:value] do
          nil -> %{stat_code: "stat_code",stat_string: "stat_string", status_color: "bg-gray-500"}
          [[stat_code,stat_string]|_rest] -> %{stat_code: stat_code_lookup(stat_code,status.datainfo),stat_string: stat_string, status_color: stat_code_to_color(stat_code)}
        end


    statmap
  end

  defp stat_code_lookup(stat_code,status_datainfo) do
    status_datainfo.members
    |> Enum.find(fn member -> member.type == "enum" end)
    |> case do
      %{members: members} ->
        members
        |> Enum.find(fn {_key, value} -> value == stat_code end)
        |> case do
          {key, _value} -> key
          nil -> :unknown
        end
      _ -> :unknown
    end
  end

  defp stat_code_to_color(stat_code) do
    cond  do
      0   <= stat_code and stat_code < 100 -> "bg-gray-500" # Disabled
      100 <= stat_code and stat_code < 200 -> "bg-green-500" # IDLE
      200 <= stat_code and stat_code < 300 -> "bg-yellow-500" # WARNING
      300 <= stat_code and stat_code < 400 -> "bg-orange-500" # BUSY
      400 <= stat_code and stat_code < 500 -> "bg-red-500" # ERROR
      true -> "bg-white"
    end
  end

end
