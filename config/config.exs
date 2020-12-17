# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :sis,
  ecto_repos: [Sis.Repo]

# Configures the endpoint
config :sis, SisWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "9p8RjYJlBTvimzQLYoGPK9EI8cgDa0mP4onKvr9IbH1suJcpkaRjpJRxCQwqt/0A",
  render_errors: [view: SisWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Sis.PubSub,
  live_view: [signing_salt: "Xwoo9+Kv"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
