defmodule SecopService.Workers.SyncNodeStates do
  @moduledoc """
  Periodic Oban worker that reconciles the `state` of SecNode records in the
  database with the actually running node services.

  Nodes marked `:active` in the DB that no longer have running services are
  transitioned to `:archived`. Archived nodes are never reactivated.

  Scheduled via Oban cron and also triggered once on application startup.
  """

  use Oban.Worker,
    queue: :default,
    unique: [period: 60],
    max_attempts: 3

  require Logger

  alias SecopService.SecNodes.SecNode
  alias SecopService.NodeSupervisor

  @impl Oban.Worker
  def perform(_job) do
    running_uuids = NodeSupervisor.list_uuid_services()

    # Get all active nodes from the DB
    active_nodes =
      SecNode
      |> Ash.Query.filter_input(%{state: %{eq: :active}})
      |> Ash.read!()

    # Archive active nodes whose UUID is not among running services
    Enum.each(active_nodes, fn node ->
      unless MapSet.member?(running_uuids, node.uuid) do
        case Ash.update(node, %{}, action: :archive) do
          {:ok, _} ->
            Logger.info(
              "SyncNodeStates: archived node #{node.equipment_id} (#{node.host}:#{node.port}) — no running services"
            )

          {:error, error} ->
            Logger.warning(
              "SyncNodeStates: failed to archive node #{node.uuid}: #{inspect(error)}"
            )
        end
      end
    end)

    :ok
  end
end
