defmodule Inmobiliaria.ClientHandler do
  @moduledoc """
  Proceso por conexión TCP.
  Se crea uno por cada cliente que se conecta.
  Lee líneas del socket, las parsea, ejecuta y responde en loop.
  """

  alias Inmobiliaria.{CommandParser, CommandHandler}

  @doc """
  Punto de entrada para cada conexión TCP entrante.
  """
  def handle_client(socket) do
    send_to(socket, banner())
    loop(socket, %{username: nil, rol: nil})
  end

  defp loop(socket, session) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        command = data |> String.trim() |> CommandParser.parse()
        {response, new_session} = CommandHandler.handle(command, session)
        send_to(socket, response <> "\n\n")
        loop(socket, new_session)

      {:error, _reason} ->
        # Cliente desconectado abruptamente — limpiar sesión si había
        if session.username != nil do
          Inmobiliaria.SessionManager.disconnect(session.username)
        end
        :ok
    end
  end

  defp send_to(socket, msg) do
    :gen_tcp.send(socket, msg)
  end

  defp banner do
    """

╔══════════════════════════════════════════════════════════════════╗
║       SISTEMA DISTRIBUIDO DE GESTIÓN INMOBILIARIA              ║
║                  Universidad del Quindío                       ║
║                   Programación III — Elixir                    ║
╠══════════════════════════════════════════════════════════════════╣
║  Escribe 'help' para ver todos los comandos disponibles.       ║
║  Escribe 'register <usuario> <clave> <rol>' para crear cuenta. ║
║  Escribe 'connect <usuario> <clave>' para iniciar sesión.      ║
╚══════════════════════════════════════════════════════════════════╝

"""
  end
end
