defmodule InmobiliariaPhoenixWeb.ErrorHTML do
  use InmobiliariaPhoenixWeb, :html

  def render("404.html", _assigns) do
    "Página no encontrada"
  end

  def render("500.html", _assigns) do
    "Error interno del servidor"
  end
end
