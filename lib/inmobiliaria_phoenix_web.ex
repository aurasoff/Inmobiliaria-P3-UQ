defmodule InmobiliariaPhoenixWeb do
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt css js)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: InmobiliariaPhoenixWeb.Layouts]

      import Plug.Conn

      use Phoenix.VerifiedRoutes,
        router: InmobiliariaPhoenixWeb.Router,
        endpoint: InmobiliariaPhoenixWeb.Endpoint,
        warn: false
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {InmobiliariaPhoenixWeb.Layouts, :app}

      use Phoenix.VerifiedRoutes,
        router: InmobiliariaPhoenixWeb.Router,
        endpoint: InmobiliariaPhoenixWeb.Endpoint,
        warn: false
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      use Phoenix.VerifiedRoutes,
        router: InmobiliariaPhoenixWeb.Router,
        endpoint: InmobiliariaPhoenixWeb.Endpoint,
        warn: false
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      use Phoenix.VerifiedRoutes,
        router: InmobiliariaPhoenixWeb.Router,
        endpoint: InmobiliariaPhoenixWeb.Endpoint,
        warn: false

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML

      import InmobiliariaPhoenixWeb.CoreComponents

      alias Phoenix.LiveView.JS
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
