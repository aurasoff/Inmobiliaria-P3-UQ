defmodule Inmobiliaria.ResultsLogger do
  @moduledoc """
  Registro de operaciones en results.log.
  Historial inmutable de todas las operaciones del sistema.
  Formato: fecha;cliente=X;responsable=Y;propiedad=Z;operacion=W;ubicacion=V;precio=U;status=T
  """

  alias Inmobiliaria.FileUtils

  @results_file "data/results.log"

  @doc """
  Registra una operación en results.log.
  params debe contener: cliente, responsable, propiedad_id, operacion, ubicacion, precio, status
  """
  def log_operation(params) do
    fecha = Date.utc_today() |> Date.to_iso8601()

    line =
      "#{fecha};" <>
        "cliente=#{params.cliente};" <>
        "responsable=#{params.responsable};" <>
        "propiedad=#{params.propiedad_id};" <>
        "operacion=#{params.operacion};" <>
        "ubicacion=#{params.ubicacion};" <>
        "precio=#{params.precio};" <>
        "status=#{params.status}"

    FileUtils.write_line(@results_file, line)
  end

  @doc """
  Retorna todas las líneas de results.log.
  """
  def get_history do
    case FileUtils.read_lines(@results_file) do
      {:ok, lines} -> lines
      {:error, _} -> []
    end
  end

  @doc """
  Ranking de compradores (operacion=compra), ordenado por cantidad desc.
  """
  def get_ranking_compradores do
    get_history()
    |> Enum.filter(&String.contains?(&1, "operacion=compra"))
    |> Enum.map(&extract_field(&1, "cliente"))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.map(fn {username, count} -> {username, count} end)
  end

  @doc """
  Ranking de vendedores (responsable en operacion=compra), ordenado desc.
  """
  def get_ranking_vendedores do
    get_history()
    |> Enum.filter(&String.contains?(&1, "operacion=compra"))
    |> Enum.map(&extract_field(&1, "responsable"))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.map(fn {username, count} -> {username, count} end)
  end

  @doc """
  Ranking de arrendadores (responsable en operacion=arriendo), ordenado desc.
  """
  def get_ranking_arrendadores do
    get_history()
    |> Enum.filter(&String.contains?(&1, "operacion=arriendo"))
    |> Enum.map(&extract_field(&1, "responsable"))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.map(fn {username, count} -> {username, count} end)
  end

  # Extrae el valor de un campo clave=valor de una línea
  defp extract_field(line, field) do
    line
    |> String.split(";")
    |> Enum.find_value("", fn part ->
      case String.split(part, "=", parts: 2) do
        [^field, value] -> value
        _ -> nil
      end
    end)
  end
end
