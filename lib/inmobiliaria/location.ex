defmodule Inmobiliaria.Location do
  @moduledoc """
  Validación de ubicaciones. Depende de FileUtils.
  Existe antes que UserManager y PropertyManager porque ambos validan ubicaciones.
  """

  alias Inmobiliaria.FileUtils

  @locations_file "data/locations.dat"

  @doc """
  Carga la lista de ubicaciones desde el archivo.
  Retorna [] si el archivo no existe o está vacío.
  """
  def load_locations do
    case FileUtils.read_lines(@locations_file) do
      {:ok, lines} -> lines
      {:error, _} -> []
    end
  end

  @doc """
  Verifica si una ubicación es válida (case-insensitive).
  """
  def valid_location?(location) do
    normalized = String.downcase(location)

    load_locations()
    |> Enum.any?(&(String.downcase(&1) == normalized))
  end

  @doc """
  Retorna la lista completa de ubicaciones válidas con formato original.
  """
  def list_locations do
    load_locations()
  end
end
