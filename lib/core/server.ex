defmodule Inmobiliaria.Server do
  @moduledoc """
  Servidor TCP principal.
  Escucha en el puerto 4000, acepta conexiones y crea un proceso
  Task por cada cliente para manejarlo en paralelo.
  """

  use GenServer

  require Logger

  @port 4000

  # ─── API pública ─────────────────────────────────────────────────────────────

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # ─── Callbacks GenServer ─────────────────────────────────────────────────────

  @impl true
  def init(_) do
    # {:packet, :line} → gen_tcp acumula bytes hasta '\n' y entrega línea completa
    opts = [:binary, {:active, false}, {:reuseaddr, true}, {:packet, :line}]

    case :gen_tcp.listen(@port, opts) do
      {:ok, listen_socket} ->
        Logger.info("Servidor inmobiliario escuchando en puerto #{@port}")
        # Iniciamos el loop de accept en un proceso separado
        {:ok, _pid} = Task.start_link(fn -> accept_loop(listen_socket) end)
        {:ok, %{listen_socket: listen_socket}}

      {:error, reason} ->
        Logger.error(" No se pudo iniciar el servidor TCP: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  # ─── Loop de aceptación ──────────────────────────────────────────────────────

  defp accept_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        # Crear proceso dedicado para este cliente
        {:ok, pid} =
          Task.start(fn ->
            Inmobiliaria.ClientHandler.handle_client(client_socket)
          end)

        # Transferir propiedad del socket al nuevo proceso
        :ok = :gen_tcp.controlling_process(client_socket, pid)

        # Volver a esperar la siguiente conexión
        accept_loop(listen_socket)

      {:error, :closed} ->
        Logger.info("Socket de escucha cerrado.")
        :ok

      {:error, reason} ->
        Logger.error("  Error aceptando conexión: #{inspect(reason)}")
        accept_loop(listen_socket)
    end
  end
end
