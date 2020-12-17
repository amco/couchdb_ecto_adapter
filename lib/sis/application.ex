defmodule Sis.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Sis.Repo,
      # Start the Telemetry supervisor
      SisWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Sis.PubSub},
      # Start the Endpoint (http/https)
      SisWeb.Endpoint
      # Start a worker by calling: Sis.Worker.start_link(arg)
      # {Sis.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    SisWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
