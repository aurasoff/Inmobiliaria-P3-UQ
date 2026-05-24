defmodule Inmobiliaria.SessionManager do
  @moduledoc """
  GenServer singleton que gestiona sesiones activas.
  Estado: %{username => %{rol, pid, connected_at}}
  """

  use GenServer

  alias Inmobiliaria.UserManager

  # ─── API pública ─────────────────────────────────────────────────────────────

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def connect(username, password, pid) do
    GenServer.call(__MODULE__, {:connect, username, password, pid})
  end

  def disconnect(username) do
    GenServer.call(__MODULE__, {:disconnect, username})
  end

  def list_sessions do
    GenServer.call(__MODULE__, :list_sessions)
  end

  def get_session(username) do
    GenServer.call(__MODULE__, {:get_session, username})
  end

  def connected?(username) do
    GenServer.call(__MODULE__, {:is_connected?, username})
  end

  # ─── Callbacks GenServer ─────────────────────────────────────────────────────

  @impl true
  def init(_) do
    {:ok, %{sessions: %{}}}
  end

  @impl true
  def handle_call({:connect, username, password, pid}, _from, state) do
    case UserManager.authenticate(username, password) do
      {:ok, user} ->
        session = %{rol: user.rol, pid: pid, connected_at: DateTime.utc_now()}
        new_state = put_in(state, [:sessions, username], session)
        {:reply, {:ok, user}, new_state}

      {:error, :not_found} ->
        # Auto-registro: extraer rol del password no aplica aquí,
        # el cliente debe usar connect username password rol
        {:reply, {:error, :not_found}, state}

      {:error, :invalid_credentials} ->
        {:reply, {:error, :invalid_credentials}, state}
    end
  end

  @impl true
  def handle_call({:disconnect, username}, _from, state) do
    if Map.has_key?(state.sessions, username) do
      new_state = update_in(state, [:sessions], &Map.delete(&1, username))
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:list_sessions, _from, state) do
    {:reply, state.sessions, state}
  end

  @impl true
  def handle_call({:get_session, username}, _from, state) do
    case Map.get(state.sessions, username) do
      nil -> {:reply, {:error, :not_found}, state}
      session -> {:reply, {:ok, session}, state}
    end
  end

  @impl true
  def handle_call({:is_connected?, username}, _from, state) do
    {:reply, Map.has_key?(state.sessions, username), state}
  end
end
