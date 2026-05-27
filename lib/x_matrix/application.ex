defmodule XMatrix.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      XMatrixWeb.Telemetry,
      XMatrix.Repo,
      {DNSCluster, query: Application.get_env(:x_matrix, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: XMatrix.PubSub},
      # Start a worker by calling: XMatrix.Worker.start_link(arg)
      # {XMatrix.Worker, arg},
      # Start to serve requests, typically the last entry
      XMatrixWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: XMatrix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    XMatrixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
