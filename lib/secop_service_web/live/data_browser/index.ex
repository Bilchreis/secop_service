defmodule SecopServiceWeb.DataBrowserLive.Index do
  use SecopServiceWeb, :live_view
  alias SecopService.Sec_Nodes

  @impl true
  def mount(_params, _session, socket) do

    socket =
      socket
      # Default sort field
      |> assign(:sort_by, :inserted_at)
      # Default sort direction
      |> assign(:sort_order, :desc)

      |> assign(:show_json_modal, false)
      |> assign(:json_content, "")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _, socket) do
    {:ok, {sec_nodes, meta}} = Sec_Nodes.list_sec_nodes(params)

    socket =
      socket
      |> assign(:sec_nodes, sec_nodes)
      |> assign(:meta, meta)


    {:noreply, socket}
  end


  @impl true
  def handle_event("open_json_modal", %{"uuid" => uuid}, socket) do
    # Find the node with the matching UUID
    node = Enum.find(socket.assigns.sec_nodes, fn n -> n.uuid == uuid end)

    # Format the JSON nicely
    formatted_json = Jason.encode!(node.describe_message, pretty: true)


    {:noreply, assign(socket, show_json_modal: true, json_content: formatted_json, json_title: "JSON Description: #{node.equipment_id} #{node.host}:#{}")}
  end

  @impl true
  def handle_event("close_json_modal", _params, socket) do
    {:noreply, assign(socket, show_json_modal: false)}
  end






    # In your LiveView module (index.ex)
  defp format_description(text) do
    text
    |> String.split("\n")
    |> Enum.map(&Phoenix.HTML.html_escape/1)
    |> Enum.intersperse(Phoenix.HTML.raw("<br>"))
  end
end
