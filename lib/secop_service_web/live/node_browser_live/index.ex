defmodule SecopServiceWeb.NodeBrowserLive.Index do
  use SecopServiceWeb, :live_view
  alias SecopService.SecNodes.SecNode

  import SecopServiceWeb.BrowseComponents

  @impl true
  def mount(params, _session, socket) do
    case Ash.get(SecNode, params["uuid"]) do
      {:ok, node} ->
        socket = assign(socket, :node, node)
        {:ok, socket}

      {:error, _reason} ->
        {:ok, assign(socket, :node, nil)}
    end

  end
end
