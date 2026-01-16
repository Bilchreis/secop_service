defmodule SecopServiceWeb.DataBrowserLive.Index do
  use SecopServiceWeb, :live_view

  alias SecopService.SecNodes.SecNode

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:show_json_modal, false)
      |> assign(:json_content, "")
      |> assign(:json_title, "")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _, socket) do
    case list_sec_nodes(params, replace_invalid_params?: true) do
      {:ok, {sec_nodes, meta}} ->
        {:noreply, assign(socket, %{sec_nodes: sec_nodes, meta: meta})}

      {:error, meta} ->
        valid_path = AshPagify.Components.build_path(~p"/browse", meta.params)
        {:noreply, push_navigate(socket, to: valid_path)}
    end
  end

  @impl true
  def handle_event("open_json_modal", %{"uuid" => uuid}, socket) do
    # Find the node with the matching UUID
    node = Enum.find(socket.assigns.sec_nodes, fn n -> n.uuid == uuid end)

    # Format the JSON nicely
    formatted_json = Jason.encode!(node.describe_message, pretty: true)

    {:noreply,
     assign(socket,
       show_json_modal: true,
       json_content: formatted_json,
       json_title: "JSON Description: #{node.equipment_id} #{node.host}:#{}"
     )}
  end

  @impl true
  def handle_event("close_json_modal", _params, socket) do
    {:noreply, assign(socket, show_json_modal: false)}
  end

  defp list_sec_nodes(params, opts) do
    AshPagify.validate_and_run(SecNode, params, [action: :node_only] ++ opts)
  end
end
