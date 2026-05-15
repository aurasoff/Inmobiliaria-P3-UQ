defmodule InmobiliariaPhoenix.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Capa de dominio (reutilizada del proyecto TCP)
      Inmobiliaria.PropertyRegistry,
      Inmobiliaria.PropertySupervisor,
      Inmobiliaria.SessionManager,

      # ← Store de usuarios en memoria (para registro/login)
      InmobiliariaPhoenix.UsuariosStore,

      # Telemetry
      InmobiliariaPhoenixWeb.Telemetry,

      # Phoenix PubSub
      {Phoenix.PubSub, name: InmobiliariaPhoenix.PubSub},

      # Phoenix Endpoint
      InmobiliariaPhoenixWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: InmobiliariaPhoenix.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        restore_active_properties()
        {:ok, pid}
      error -> error
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    InmobiliariaPhoenixWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp restore_active_properties do
    Inmobiliaria.PropertyManager.load_properties()
    |> Enum.reject(&(&1.estado in ["vendida", "arrendada"]))
    |> Enum.each(&Inmobiliaria.PropertySupervisor.start_property/1)
  end
end
