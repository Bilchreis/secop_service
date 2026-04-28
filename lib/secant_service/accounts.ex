defmodule SecantService.Accounts do
  use Ash.Domain, otp_app: :secant_service, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource SecantService.Accounts.Token
    resource SecantService.Accounts.User
    resource SecantService.Accounts.ApiKey
  end
end
