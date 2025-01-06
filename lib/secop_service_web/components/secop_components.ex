defmodule SECoPComponents do
  use Phoenix.Component
  alias Jason


  attr :equipment_id, :string, required: true
  attr :pubsub_topic, :string, required: true
  attr :current, :boolean, default: false

  def node_button(assigns) do
    ~H"""
    <button class={
      if @current do
        "bg-green-500 hover:bg-green-700 text-white text-left font-bold py-2 px-4 rounded"
      else
        "bg-blue-500 hover:bg-blue-700 text-white text-left font-bold py-2 px-4 rounded"
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
        "min-w-full bg-green-500 hover:bg-green-700 text-white text-left font-bold py-2 px-4 rounded"
      else
        "min-w-full bg-blue-500 hover:bg-blue-700 text-white text-left font-bold py-2 px-4 rounded"
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
          [[stat_code,stat_string]|_rest] -> %{stat_code: stat_code_lookup(stat_code,status.datainfo),stat_string: stat_string, status_color: "bg-green-500"}
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

end
