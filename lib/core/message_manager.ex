defmodule Inmobiliaria.MessageManager do
  alias Inmobiliaria.FileUtils

  @messages_file "data/messages.log"

  # Formato: timestamp;propiedad_id;remitente;destinatario;mensaje;reply_to
  # reply_to es "" si es mensaje nuevo, o timestamp del mensaje al que responde

  def send_message(property_id, sender, recipient, message, reply_to \\ "") do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    line = "#{timestamp};#{property_id};#{sender};#{recipient};#{message};#{reply_to}"
    FileUtils.write_line(@messages_file, line)
  end

  def get_messages_for_property(property_id) do
    case FileUtils.read_lines(@messages_file) do
      {:ok, lines} ->
        lines
        |> Enum.reject(&(String.trim(&1) == ""))
        |> Enum.filter(fn line ->
          case String.split(line, ";", parts: 6) do
            [_, pid, _, _, _, _] -> pid == property_id
            _ -> false
          end
        end)
        |> Enum.map(&parsear_mensaje/1)

      {:error, _} ->
        []
    end
  end

  def get_messages_for_user(username) do
    case FileUtils.read_lines(@messages_file) do
      {:ok, lines} ->
        lines
        |> Enum.reject(&(String.trim(&1) == ""))
        |> Enum.map(&parsear_mensaje/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(fn m ->
          # Solo mensajes donde YO soy remitente O destinatario directo
          m.sender == username || m.recipient == username
        end)

      {:error, _} ->
        []
    end
  end

  defp parsear_mensaje(line) do
    case String.split(line, ";", parts: 6) do
      [timestamp, property_id, sender, recipient, message, reply_to] ->
        %{
          timestamp: timestamp,
          property_id: property_id,
          sender: sender,
          recipient: recipient,
          message: message,
          reply_to: reply_to
        }

      _ ->
        nil
    end
  end
end
