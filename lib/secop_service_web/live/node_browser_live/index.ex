defmodule SecopServiceWeb.NodeBrowserLive.Index do
  use SecopServiceWeb, :live_view
  alias SecopService.Sec_Nodes

  import SecopServiceWeb.BrowseComponents

  @impl true
  def mount(params, _session, socket) do
    socket =
      if Sec_Nodes.node_exists?(params["uuid"]) do
        socket
        |> assign(:node, Sec_Nodes.get_sec_node_by_uuid(params["uuid"]))
      else
        socket
        |> assign(:node, nil)
      end

    {:ok, socket}
  end
end
