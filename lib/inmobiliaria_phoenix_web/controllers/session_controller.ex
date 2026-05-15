defmodule InmobiliariaPhoenixWeb.SessionController do
  use InmobiliariaPhoenixWeb, :controller

  # El LiveView redirige aquí con ?username=...&rol=...
  # Este controller escribe la sesión (algo que LiveView no puede hacer)
  def create(conn, %{"username" => username, "rol" => rol}) do
    destino =
      case rol do
        "cliente"    -> "/cliente"
        "vendedor"   -> "/propietario"
        "arrendador" -> "/propietario"
        _            -> "/cliente"
      end

    conn
    |> put_session(:current_user, %{"username" => username, "rol" => rol})
    |> redirect(to: destino)
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/login")
  end
end
