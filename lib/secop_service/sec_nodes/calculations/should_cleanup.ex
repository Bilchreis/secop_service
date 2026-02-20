defmodule SecopService.SecNodes.Calculations.ShouldCleanup do
  use Ash.Resource.Calculation

  @impl true
  def expression(_opts, _context) do
    retention_days = Application.get_env(:secop_service, :data_retention_days, 30)

    expr(state == :archived and favourite == false and updated_at < ago(^retention_days, :day))
  end
end
