import Config

config :inmobiliaria_phoenix, InmobiliariaPhoenixWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "inmoSecretKeyBase1234567890abcdefghijklmnopqrstuvwxyz1234567890ab",
  watchers: []

config :logger, level: :debug
