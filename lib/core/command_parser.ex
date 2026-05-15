defmodule Inmobiliaria.CommandParser do
  @moduledoc """
  Parseo de comandos del usuario.
  Función pura: texto crudo → tupla estructurada.
  No llama a ningún otro módulo.
  """

  @doc """
  Parsea una línea de texto y retorna la tupla de comando correspondiente.
  """
  def parse(input) when is_binary(input) do
    input
    |> String.trim()
    |> String.split(" ", parts: 2)
    |> do_parse()
  end

  # ─── Casos de parseo ─────────────────────────────────────────────────────────

  defp do_parse(["connect", rest]) do
    case String.split(rest, " ") do
      [username, password] -> {:connect, username, password}
      [username, password, _rol] -> {:connect, username, password}
      _ -> {:unknown, "connect " <> rest}
    end
  end

  defp do_parse(["disconnect"]), do: :disconnect
  defp do_parse(["disconnect" | _]), do: :disconnect

  defp do_parse(["register", rest]) do
    case String.split(rest, " ") do
      [username, password, rol] -> {:register, username, password, rol}
      _ -> {:unknown, "register " <> rest}
    end
  end

  defp do_parse(["list_properties"]), do: :list_properties

  defp do_parse(["list_properties", rest]) do
    filters = parse_kv_args(String.split(rest, " "))
    {:list_properties, filters}
  end

  defp do_parse(["publish_property", rest]) do
    args = parse_kv_args(String.split(rest, " "))
    {:publish_property, args}
  end

  defp do_parse(["buy_property", rest]) do
    {:buy_property, String.trim(rest)}
  end

  defp do_parse(["rent_property", rest]) do
    {:rent_property, String.trim(rest)}
  end

  defp do_parse(["send_message", rest]) do
    case String.split(rest, " ", parts: 2) do
      [property_id, message] -> {:send_message, property_id, message}
      _ -> {:unknown, "send_message " <> rest}
    end
  end

  defp do_parse(["get_messages", rest]) do
    {:get_messages, String.trim(rest)}
  end

  defp do_parse(["my_score"]), do: :my_score
  defp do_parse(["my_score" | _]), do: :my_score

  defp do_parse(["ranking"]), do: :ranking
  defp do_parse(["ranking" | _]), do: :ranking

  defp do_parse(["ranking_compradores"]), do: :ranking_compradores
  defp do_parse(["ranking_vendedores"]), do: :ranking_vendedores
  defp do_parse(["ranking_arrendadores"]), do: :ranking_arrendadores

  defp do_parse(["help"]), do: :help
  defp do_parse(["help" | _]), do: :help

  defp do_parse(["sessions"]), do: :sessions

  defp do_parse([cmd | rest]) do
    raw = if rest == [], do: cmd, else: cmd <> " " <> Enum.join(rest, " ")
    {:unknown, raw}
  end

  defp do_parse([]) do
    {:unknown, ""}
  end

  # ─── Helpers ─────────────────────────────────────────────────────────────────

  defp parse_kv_args(parts) do
    parts
    |> Enum.reduce(%{}, fn part, acc ->
      case String.split(part, "=", parts: 2) do
        [k, v] -> Map.put(acc, String.to_atom(k), v)
        _ -> acc
      end
    end)
  end
end
