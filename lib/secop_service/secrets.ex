defmodule SecopService.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        SecopService.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:secop_service, :token_signing_secret)
  end
end
