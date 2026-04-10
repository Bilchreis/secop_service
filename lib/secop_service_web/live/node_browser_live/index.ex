defmodule SecopServiceWeb.NodeBrowserLive.Index do
  use SecopServiceWeb, :live_view
  alias SecopService.SecNodes.SecNode
  alias SecopServiceWeb.Components.HistoryDB

  import SecopServiceWeb.BrowseComponents

  @impl true
  def mount(params, _session, socket) do
    case Ash.get(SecNode, params["uuid"]) do
      {:ok, node} ->
        socket =
          socket
          |> assign(:node, node)
          |> assign(:selected_parameter, nil)

        {:ok, socket}

      {:error, _reason} ->
        {:ok, assign(socket, node: nil, selected_parameter: nil)}
    end
  end

  @impl true
  def handle_event("show_parameter_graph", %{"parameter_id" => id}, socket) do
    parameter =
      Enum.find_value(socket.assigns.node.modules, fn module ->
        Enum.find(module.parameters, fn p -> to_string(p.id) == id end)
      end)

    {:noreply, assign(socket, :selected_parameter, parameter)}
  end

  @impl true
  def handle_event("close_parameter_graph", _params, socket) do
    {:noreply, assign(socket, :selected_parameter, nil)}
  end
end
