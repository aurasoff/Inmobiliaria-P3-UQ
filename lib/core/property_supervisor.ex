defmodule Inmobiliaria.PropertySupervisor do
  @moduledoc """
  DynamicSupervisor de propiedades.
  Sus hijos se agregan en tiempo de ejecución — cada vez que un vendedor
  publica una propiedad, este supervisor crea un nuevo proceso hijo.
  Estrategia :one_for_one: si un proceso falla, solo ese se reinicia.
  """

  use DynamicSupervisor

  alias Inmobiliaria.Property

  # ─── API pública ─────────────────────────────────────────────────────────────

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Inicia un nuevo proceso Property bajo este supervisor."
  def start_property(property) do
    DynamicSupervisor.start_child(__MODULE__, {Property, property})
  end

  @doc "Termina el proceso de una propiedad por su id."
  def stop_property(id) do
    case Registry.lookup(Inmobiliaria.PropertyRegistry, id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :not_found}
    end
  end

  @doc "Lista los ids de todas las propiedades con proceso activo."
  def list_active_properties do
    Registry.select(Inmobiliaria.PropertyRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  # ─── Callback DynamicSupervisor ──────────────────────────────────────────────

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
