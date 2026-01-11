defmodule SecopService.Accounts do
  use Ash.Domain, otp_app: :secop_service, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource SecopService.Accounts.Token
    resource SecopService.Accounts.User
    resource SecopService.Accounts.ApiKey
  end
end
