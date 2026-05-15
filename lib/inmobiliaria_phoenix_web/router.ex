defmodule InmobiliariaPhoenixWeb.Router do
  use InmobiliariaPhoenixWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {InmobiliariaPhoenixWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", InmobiliariaPhoenixWeb do
    pipe_through :browser

    # Autenticacion
    live "/",         AuthLive, :login
    live "/login",    AuthLive, :login
    live "/register", AuthLive, :register

    # ← Nueva ruta: LiveView autentica y redirige aquí,
    #   el controller escribe la sesión
    get "/session", SessionController, :create

    # Cerrar sesion
    get "/logout", SessionController, :delete

    # Panel cliente
    live "/cliente",             ClienteLive, :index
    live "/cliente/buscar",      ClienteLive, :buscar
    live "/cliente/comprar/:id", ClienteLive, :comprar
    live "/cliente/mensajes",    ClienteLive, :mensajes

    # Panel vendedor / arrendador
    live "/propietario",           PropietarioLive, :index
    live "/propietario/publicar",  PropietarioLive, :publicar
    live "/propietario/mensajes",  PropietarioLive, :mensajes

    # Ranking
    live "/ranking", RankingLive, :index
  end
end
