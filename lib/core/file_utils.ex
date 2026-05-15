defmodule Inmobiliaria.FileUtils do
  @moduledoc """
  Utilidades genéricas de lectura y escritura de archivos.
  Es el módulo más bajo del stack — todos los demás módulos de persistencia lo usan.
  """

  @doc """
  Lee el archivo línea por línea. Elimina espacios en blanco y líneas vacías.
  Retorna {:ok, [String.t()]} | {:error, :not_found}
  """
  def read_lines(path) do
    case File.read(path) do
      {:ok, content} ->
        lines =
          content
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        {:ok, lines}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Abre el archivo en modo :append y escribe la línea seguida de \\n.
  NUNCA sobreescribe el archivo completo.
  """
  def write_line(path, line) do
    File.write(path, line <> "\n", [:append])
  end

  @doc """
  Sobreescribe el archivo COMPLETO con una lista de líneas.
  Usado para actualizar un registro existente.
  """
  def overwrite_lines(path, lines) do
    content = Enum.join(lines, "\n") <> "\n"
    File.write(path, content)
  end

  @doc """
  Wrapper simple alrededor de File.exists?/1.
  """
  def file_exists?(path) do
    File.exists?(path)
  end
end
