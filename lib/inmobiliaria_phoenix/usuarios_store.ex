defmodule InmobiliariaPhoenix.UsuariosStore do
  use Agent

  @ruta_archivo "data/users.dat"

  @usuarios_iniciales [
    %{"username" => "cliente",    "password" => "123", "rol" => "cliente",    "puntaje" => 0},
    %{"username" => "vendedor",   "password" => "123", "rol" => "vendedor",   "puntaje" => 0},
    %{"username" => "arrendador", "password" => "123", "rol" => "arrendador", "puntaje" => 0}
  ]

  # ── Inicio ─────────────────────────────────────────────────────────────────

  def start_link(_opts) do
    usuarios = cargar_desde_archivo()
    Agent.start_link(fn -> usuarios end, name: __MODULE__)
  end

  # ── API pública ────────────────────────────────────────────────────────────

  def todos do
    Agent.get(__MODULE__, & &1)
  end

  def existe?(username) do
    Enum.any?(todos(), fn u -> u["username"] == username end)
  end

  def buscar(username, password) do
    Enum.find(todos(), fn u ->
      u["username"] == username && u["password"] == password
    end)
  end

  def agregar(username, password, rol) do
    nuevo = %{"username" => username, "password" => password, "rol" => rol, "puntaje" => 0}

    Agent.update(__MODULE__, fn lista -> lista ++ [nuevo] end)

    guardar_en_archivo(todos())
  end

  def sumar_puntaje(username, puntos) do
    Agent.update(__MODULE__, fn lista ->
      Enum.map(lista, fn u ->
        if u["username"] == username do
          %{u | "puntaje" => u["puntaje"] + puntos}
        else
          u
        end
      end)
    end)

    guardar_en_archivo(todos())
  end

  # ── Persistencia ───────────────────────────────────────────────────────────

  defp cargar_desde_archivo do
    if File.exists?(@ruta_archivo) do
      @ruta_archivo
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&parsear_linea/1)
      |> Enum.reject(&is_nil/1)
    else
      # Si no existe el archivo, usar los iniciales y crearlo
      File.mkdir_p!("data")
      guardar_en_archivo(@usuarios_iniciales)
      @usuarios_iniciales
    end
  end

  defp parsear_linea(linea) do
  case String.split(String.trim(linea), ";") do
    [username, rol, password, puntaje] when username != "" ->
      puntaje_int =
        case Integer.parse(puntaje) do
          {n, _} -> n
          :error  -> 0
        end

      %{
        "username" => username,
        "rol"      => rol,
        "password" => password,
        "puntaje"  => puntaje_int
      }

    _ ->
      nil
  end
end

  defp guardar_en_archivo(usuarios) do
    File.mkdir_p!("data")

    contenido =
      usuarios
      |> Enum.map(fn u ->
        "#{u["username"]};#{u["rol"]};#{u["password"]};#{u["puntaje"]}"
      end)
      |> Enum.join("\n")

    File.write!(@ruta_archivo, contenido)
  end
end
