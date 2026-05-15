import Config

if config_env() == :prod do
  config :inmobiliaria_phoenix, InmobiliariaPhoenixWeb.Endpoint,
    secret_key_base: System.get_env("SECRET_KEY_BASE") ||
      "inmoSecretKeyBase1234567890abcdefghijklmnopqrstuvwxyz1234567890ab"
end
