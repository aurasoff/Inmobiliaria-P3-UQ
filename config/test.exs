import Config

config :inmobiliaria_phoenix, InmobiliariaPhoenixWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "inmoTestSecretKey1234567890abcdefghijklmnopqrstuvwxyz1234567890ab"

config :logger, level: :warning
