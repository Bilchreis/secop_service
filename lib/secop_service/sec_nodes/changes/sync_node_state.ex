defmodule SecopService.SecNodes.Changes.SyncNodeState do
  use Ash.Resource.Change

  require Logger

  alias Ash.Changeset
  alias SecopService.NodeSupervisor

  @impl true
  def change(changeset, _opts, _context) do
    node = changeset.data
    running_uuids = NodeSupervisor.list_uuid_services()

    Logger.debug(
      "SyncNodeStates: checking node #{node.equipment_id} (#{node.host}:#{node.port}) — running UUIDs: #{inspect(running_uuids)}"
    )

    if MapSet.member?(running_uuids, node.uuid) do
      changeset
    else
      Logger.info(
        "SyncNodeStates: archiving node #{node.equipment_id} (#{node.host}:#{node.port}) — no running services"
      )

      changeset
      |> AshStateMachine.transition_state(:processed)
      |> run_archive_trigger()
    end
  end

  defp run_archive_trigger(changeset) do
    trigger = AshOban.Info.oban_trigger(changeset.resource, :recalculate_storage_on_archive)

    if !trigger do
      raise "No such trigger :recalculate_storage_on_archive for resource #{inspect(changeset.resource)}"
    end

    Changeset.after_action(changeset, fn _changeset, result ->
      AshOban.run_trigger(result, trigger)
      {:ok, result}
    end)
  end
end
