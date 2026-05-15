import Config

config :inmobiliaria_phoenix, InmobiliariaPhoenixWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: InmobiliariaPhoenixWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: InmobiliariaPhoenix.PubSub,
  live_view: [signing_salt: "inmoLiveSalt"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
