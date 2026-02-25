defmodule SecopService.StartupTriggerRunner do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    send(self(), :run_sync_node_states)
    {:ok, state}
  end

  @impl true
  def handle_info(:run_sync_node_states, state) do
    # ensures that all previously active nodes are transitioned to archived
    # and have their storage recalculated on startup
    AshOban.schedule_and_run_triggers({SecopService.SecNodes.SecNode, :sync_node_states})

    # any Nodes that were left on processed state (e.g. due to a crash during recalculation) will have their storage
    # recalculated on the next transition to archived
    AshOban.schedule_and_run_triggers({SecopService.SecNodes.SecNode, :recalculate_storage_on_archive})
    {:noreply, state}
  end
end
