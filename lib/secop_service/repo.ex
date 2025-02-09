defmodule SecopService.Repo do
  use Ecto.Repo,
    otp_app: :secop_service,
    adapter: Ecto.Adapters.Postgres
end
