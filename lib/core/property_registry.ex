defmodule Inmobiliaria.PropertyRegistry do
  @moduledoc """
  Registry de procesos de propiedades activas.
  No tiene lógica propia; actúa como directorio de procesos.
  Debe iniciar ANTES que PropertySupervisor.
  """

  def child_spec(_opts) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__
    )
  end
end
