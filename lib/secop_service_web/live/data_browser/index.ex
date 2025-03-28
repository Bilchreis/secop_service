defmodule SecopServiceWeb.DataBrowserLive.Index do
  use SecopServiceWeb, :live_view
  alias SecopService.Sec_Nodes

  @impl true
  def mount(_params, _session, socket) do
    # Get your sec_nodes data
    sec_nodes = Sec_Nodes.list_sec_nodes()

    socket =
      socket
      |> assign(:sec_nodes, sec_nodes)
      # Default sort field
      |> assign(:sort_by, :inserted_at)
      # Default sort direction
      |> assign(:sort_order, :desc)

    {:ok, socket}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    # Toggle sort order if clicking the same field
    {sort_by, sort_order} =
      if socket.assigns.sort_by == field do
        {field, toggle_sort_order(socket.assigns.sort_order)}
      else
        {field, :asc}
      end

    sorted_nodes = sort_nodes(socket.assigns.sec_nodes, sort_by, sort_order)

    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:sort_order, sort_order)
      |> assign(:sec_nodes, sorted_nodes)

    {:noreply, socket}
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(:desc), do: :asc

  defp sort_nodes(nodes, field, order) do
    Enum.sort_by(nodes, &Map.get(&1, field), sort_direction(order))
  end

  defp sort_direction(:asc), do: :asc
  defp sort_direction(:desc), do: :desc

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "SEC Nodes")
  end
end
