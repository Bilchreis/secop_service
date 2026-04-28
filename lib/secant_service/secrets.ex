defmodule SecantService.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        SecantService.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:secant_service, :token_signing_secret)
  end
end
