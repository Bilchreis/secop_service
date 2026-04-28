defmodule SecantService.SecNodes.Calculations.ShouldPurge do
  use Ash.Resource.Calculation

  @impl true
  def expression(_opts, _context) do
    trash_retention_days = Application.get_env(:secant_service, :trash_retention_days, 7)

    expr(state == :trashed and updated_at < ago(^trash_retention_days, :day))
  end
end
