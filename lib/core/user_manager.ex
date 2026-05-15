defmodule Inmobiliaria.UserManager do
  @moduledoc """
  Gestión de usuarios en users.dat.
  Maneja registro, autenticación y actualización de puntajes.
  """

  alias Inmobiliaria.FileUtils

  @users_file "data/users.dat"

  defstruct [:username, :rol, :password, :puntaje]

  @doc """
  Convierte una línea del archivo en un struct %UserManager{}.
  Formato: username;rol;password;puntaje
  """
  def parse_user(line) do
    [username, rol, password, puntaje] = String.split(line, ";")

    %__MODULE__{
      username: username,
      rol: rol,
      password: password,
      puntaje: String.to_integer(puntaje)
    }
  end

  @doc """
  Convierte un struct %UserManager{} de vuelta a una línea de texto.
  """
  def serialize_user(user) do
    "#{user.username};#{user.rol};#{user.password};#{user.puntaje}"
  end

  @doc """
  Carga todos los usuarios desde users.dat.
  """
  def load_users do
    case FileUtils.read_lines(@users_file) do
      {:ok, lines} -> Enum.map(lines, &parse_user/1)
      {:error, _} -> []
    end
  end

  @doc """
  Busca un usuario por username (case-sensitive).
  """
  def find_user(username) do
    case Enum.find(load_users(), &(&1.username == username)) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @doc """
  Registra un nuevo usuario. Retorna :ok | {:error, :already_exists}.
  """
  def register_user(username, rol, password) do
    case find_user(username) do
      {:ok, _} ->
        {:error, :already_exists}

      {:error, :not_found} ->
        user = %__MODULE__{
          username: username,
          rol: rol,
          password: password,
          puntaje: 0
        }

        FileUtils.write_line(@users_file, serialize_user(user))
    end
  end

  @doc """
  Autentica un usuario con username y password.
  """
  def authenticate(username, password) do
    case find_user(username) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, user} ->
        if user.password == password do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  @doc """
  Suma points al puntaje del usuario y reescribe el archivo completo.
  """
  def update_score(username, points) do
    users = load_users()

    updated_users =
      Enum.map(users, fn user ->
        if user.username == username do
          %{user | puntaje: user.puntaje + points}
        else
          user
        end
      end)

    lines = Enum.map(updated_users, &serialize_user/1)
    FileUtils.overwrite_lines(@users_file, lines)
  end

  @doc """
  Retorna ranking de usuarios ordenado por puntaje descendente.
  """
  def get_ranking do
    load_users()
    |> Enum.sort_by(& &1.puntaje, :desc)
    |> Enum.map(&{&1.username, &1.rol, &1.puntaje})
  end
end
