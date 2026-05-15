defmodule Inmobiliaria.Application do
  @moduledoc """
  Módulo Application — define el árbol de supervisión OTP completo.
  El orden de inicio es crítico: PropertyRegistry antes que PropertySupervisor.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # 1. Registry de propiedades (debe iniciar PRIMERO)
      Inmobiliaria.PropertyRegistry,
      # 2. DynamicSupervisor de propiedades
      Inmobiliaria.PropertySupervisor,
      # 3. Manejador de sesiones activas
      Inmobiliaria.SessionManager,
      # 4. Servidor TCP
      Inmobiliaria.Server
    ]

    opts = [strategy: :one_for_one, name: Inmobiliaria.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Restaurar propiedades activas desde disco al arrancar
        restore_active_properties()
        {:ok, pid}

      error ->
        error
    end
  end

  defp restore_active_properties do
    Inmobiliaria.PropertyManager.load_properties()
    |> Enum.reject(&(&1.estado in ["vendida", "arrendada"]))
    |> Enum.each(&Inmobiliaria.PropertySupervisor.start_property/1)
  end
end
