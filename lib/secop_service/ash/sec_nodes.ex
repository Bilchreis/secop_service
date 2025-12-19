defmodule SecopService.Ash.SecNodes do
  use Ash.Domain,
    otp_app: :secop_service

  resources do
    resource SecopService.Ash.SecNodes.ApiKey
    resource SecopService.Ash.SecNodes.Command
    resource SecopService.Ash.SecNodes.Module
    resource SecopService.Ash.SecNodes.ParameterValuesArrayBool
    resource SecopService.Ash.SecNodes.ParameterValuesArrayDouble
    resource SecopService.Ash.SecNodes.ParameterValuesArrayInt
    resource SecopService.Ash.SecNodes.ParameterValuesArrayString
    resource SecopService.Ash.SecNodes.ParameterValuesBool
    resource SecopService.Ash.SecNodes.ParameterValuesDouble
    resource SecopService.Ash.SecNodes.ParameterValuesInt
    resource SecopService.Ash.SecNodes.ParameterValuesJson
    resource SecopService.Ash.SecNodes.ParameterValuesString
    resource SecopService.Ash.SecNodes.Parameter
    resource SecopService.Ash.SecNodes.SecNode
    resource SecopService.Ash.SecNodes.Token
    resource SecopService.Ash.SecNodes.User
  end
end
