defmodule SecopService.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SecopServiceWeb.Telemetry,
      SecopService.Repo,
      {DNSCluster, query: Application.get_env(:secop_service, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SecopService.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: SecopService.Finch},
      {Registry, keys: :unique, name: Registry.NodeDBWriter},
      {Registry, keys: :unique, name: Registry.NodeValues},
      {Registry, keys: :unique, name: Registry.NodeServices},
      {Registry, keys: :unique, name: Registry.PlotCacheSupervisor},
      {Registry, keys: :unique, name: Registry.PlotCacheDispatcher},
      {Registry, keys: :unique, name: Registry.PlotCache},
      SecopService.NodeManager,
      {SecopService.NodeSupervisor, []},
      # Start a worker by calling: SecopService.Worker.start_link(arg)
      # {SecopService.Worker, arg},
      # Start to serve requests, typically the last entry
      SecopServiceWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SecopService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SecopServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
