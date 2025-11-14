# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :secop_service,
  ecto_repos: [SecopService.Repo],
  generators: [timestamp_type: :utc_datetime]

# Add Flop configuration
config :flop, repo: SecopService.Repo

# Configures the endpoint
config :secop_service, SecopServiceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SecopServiceWeb.ErrorHTML, json: SecopServiceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SecopService.PubSub,
  live_view: [signing_salt: "JEmZCdo/"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :secop_service, SecopService.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.5",
  secop_service: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  secop_service: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]


# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :pythonx, :uv_init,
  pyproject_toml: """
  [project]
  name = "secop_checker"
  version = "0.0.1"
  requires-python = "==3.13.*"
  dependencies = [
    "secop_check @ git+https://github.com/Bilchreis/secop_check.git"
  ]
  """

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
