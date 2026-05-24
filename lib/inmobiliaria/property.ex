defmodule Inmobiliaria.Property do
  @moduledoc """
  GenServer de una propiedad individual.
  Cada propiedad publicada es un proceso vivo con su propio estado.
  La atomicidad de handle_call resuelve condiciones de carrera sin locks.
  """

  use GenServer

  alias Inmobiliaria.{PropertyManager, UserManager, ResultsLogger}

  # ─── API pública ────────────────────────────────────────────────────────────

  def start_link(property) do
    GenServer.start_link(__MODULE__, property, name: via_tuple(property.id))
  end

  def get_state(property_id) do
    GenServer.call(via_tuple(property_id), :get_state)
  end

  def buy(property_id, client_username) do
    GenServer.call(via_tuple(property_id), {:buy, client_username})
  end

  def rent(property_id, client_username) do
    GenServer.call(via_tuple(property_id), {:rent, client_username})
  end

  # ─── Callbacks GenServer ─────────────────────────────────────────────────────

  @impl true
  def init(property) do
    {:ok, %{property: property, owner_pid: nil}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.property, state}
  end

  @impl true
  def handle_call({:buy, client_username}, _from, state) do
    property = state.property

    if property.estado != "disponible" do
      {:reply, {:error, :not_available}, state}
    else
      updated_property = %{property | estado: "vendida"}

      # Operación atómica: actualizar disco y puntajes
      PropertyManager.update_property_state(property.id, "vendida")

      UserManager.update_score(client_username, 10)
      UserManager.update_score(property.propietario, 15)

      ResultsLogger.log_operation(%{
        cliente: client_username,
        responsable: property.propietario,
        propiedad_id: property.id,
        operacion: "compra",
        ubicacion: property.ubicacion,
        precio: property.precio,
        status: "Completada"
      })

      {:reply, {:ok, updated_property}, %{state | property: updated_property}}
    end
  end

  @impl true
  def handle_call({:rent, client_username}, _from, state) do
    property = state.property

    if property.estado != "disponible" do
      {:reply, {:error, :not_available}, state}
    else
      updated_property = %{property | estado: "arrendada"}

      PropertyManager.update_property_state(property.id, "arrendada")

      UserManager.update_score(client_username, 10)
      UserManager.update_score(property.propietario, 15)

      ResultsLogger.log_operation(%{
        cliente: client_username,
        responsable: property.propietario,
        propiedad_id: property.id,
        operacion: "arriendo",
        ubicacion: property.ubicacion,
        precio: property.precio,
        status: "Completada"
      })

      {:reply, {:ok, updated_property}, %{state | property: updated_property}}
    end
  end

  @impl true
  def handle_call({:update_state, new_state}, _from, state) do
    updated = %{state | property: %{state.property | estado: new_state}}
    {:reply, :ok, updated}
  end

  # ─── Helpers privados ────────────────────────────────────────────────────────

  defp via_tuple(id) do
    {:via, Registry, {Inmobiliaria.PropertyRegistry, id}}
  end
end
