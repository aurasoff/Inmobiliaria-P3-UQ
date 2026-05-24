defmodule Inmobiliaria.PropertyManager do
  @moduledoc """
  Registro y consulta de propiedades en properties.dat.
  Maneja el estado 'en frío' de las propiedades.
  """

  alias Inmobiliaria.FileUtils

  @properties_file "data/properties.dat"

  defstruct [:id, :tipo, :modalidad, :ubicacion, :precio,
             :habitaciones, :area, :estado, :propietario]

  @doc """
  Convierte una línea del archivo en un struct %PropertyManager{}.
  Formato: id;tipo;modalidad;ubicacion;precio;habitaciones;area;estado;propietario
  """
  def parse_property(line) do
    [id, tipo, modalidad, ubicacion, precio, habitaciones, area, estado, propietario] =
      String.split(line, ";")

    %__MODULE__{
      id: id,
      tipo: tipo,
      modalidad: modalidad,
      ubicacion: ubicacion,
      precio: String.to_integer(precio),
      habitaciones: String.to_integer(habitaciones),
      area: String.to_float(area),
      estado: estado,
      propietario: propietario
    }
  end

  @doc """
  Convierte un struct %PropertyManager{} de vuelta a una línea de texto.
  """
  def serialize_property(property) do
    "#{property.id};#{property.tipo};#{property.modalidad};#{property.ubicacion};" <>
      "#{property.precio};#{property.habitaciones};#{property.area};#{property.estado};#{property.propietario}"
  end

  @doc """
  Carga todas las propiedades desde properties.dat.
  """
  def load_properties do
    case FileUtils.read_lines(@properties_file) do
      {:ok, lines} -> Enum.map(lines, &parse_property/1)
      {:error, _} -> []
    end
  end

  @doc """
  Busca una propiedad por su id exacto.
  """
  def find_property(id) do
    case Enum.find(load_properties(), &(&1.id == id)) do
      nil -> {:error, :not_found}
      property -> {:ok, property}
    end
  end

  @doc """
  Guarda una propiedad nueva. Retorna :ok | {:error, :already_exists}.
  """
  def save_property(property) do
    case find_property(property.id) do
      {:ok, _} ->
        {:error, :already_exists}

      {:error, :not_found} ->
        FileUtils.write_line(@properties_file, serialize_property(property))
    end
  end

  @doc """
  Aplica el patrón leer-modificar-escribir para actualizar el estado de una propiedad.
  """
  def update_property_state(id, new_state) do
    properties = load_properties()

    case Enum.find(properties, &(&1.id == id)) do
      nil ->
        {:error, :not_found}

      _found ->
        updated =
          Enum.map(properties, fn p ->
            if p.id == id, do: %{p | estado: new_state}, else: p
          end)

        lines = Enum.map(updated, &serialize_property/1)
        FileUtils.overwrite_lines(@properties_file, lines)
    end
  end

  @doc """
  Lista propiedades disponibles con filtros opcionales.
  Filtros: tipo, modalidad, ubicacion, precio_min, precio_max.
  """
  def list_available(filters \\ %{}) do
    load_properties()
    |> Enum.filter(&(&1.estado == "disponible"))
    |> Enum.filter(fn p -> apply_filters(p, filters) end)
  end

  defp apply_filters(property, filters) do
    Enum.all?(filters, fn
      {:tipo, v} -> String.downcase(property.tipo) == String.downcase(v)
      {:modalidad, v} -> String.downcase(property.modalidad) == String.downcase(v)
      {:ubicacion, v} -> String.downcase(property.ubicacion) == String.downcase(v)
      {:precio_min, v} -> property.precio >= parse_number(v)
      {:precio_max, v} -> property.precio <= parse_number(v)
      _ -> true
    end)
  end

  defp parse_number(v) when is_integer(v), do: v
  defp parse_number(v) when is_binary(v), do: String.to_integer(v)

  @doc """
  Genera un ID único para una nueva propiedad.
  """
  def generate_id do
    "prop" <> Integer.to_string(System.unique_integer([:positive]))
  end
  @doc """
    Alias de update_property_state para compatibilidad con PropietarioLive.
  """
  def update_estado(id, nuevo_estado) do
    update_property_state(id, nuevo_estado)
  end
end
