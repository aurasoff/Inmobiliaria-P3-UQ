defmodule InmobiliariaPhoenixWeb.AuthLive do
  use InmobiliariaPhoenixWeb, :live_view

  alias InmobiliariaPhoenix.UsuariosStore

  # ─────────────────────────────────────────────
  # MOUNT
  # ─────────────────────────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: nil, success: nil)}
  end

  # ─────────────────────────────────────────────
  # HANDLE PARAMS
  # ─────────────────────────────────────────────

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, error: nil, success: nil)}
  end

  # ─────────────────────────────────────────────
  # EVENTOS
  # ─────────────────────────────────────────────

  @impl true
  def handle_event("login", %{"username" => username, "password" => password}, socket) do
    case UsuariosStore.buscar(username, password) do
      nil ->
        {:noreply, assign(socket, error: "Usuario o contraseña incorrectos.", success: nil)}

      usuario ->
        {:noreply,
         redirect(socket,
           to: "/session?username=#{usuario["username"]}&rol=#{usuario["rol"]}"
         )}
    end
  end

  @impl true
  def handle_event("register", %{"username" => u, "password" => p, "rol" => r}, socket) do
    if UsuariosStore.existe?(u) do
      {:noreply, assign(socket, error: "El usuario '#{u}' ya existe.", success: nil)}
    else
      UsuariosStore.agregar(u, p, r)

      # No navegamos — mostramos el mensaje en la misma página
      {:noreply,
       assign(socket,
         error: nil,
         success: "¡Cuenta creada! Ya puedes iniciar sesión."
       )}
    end
  end

  # ─────────────────────────────────────────────
  # RENDER
  # ─────────────────────────────────────────────

  @impl true
  def render(%{live_action: :register} = assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-100">
      <div class="bg-white shadow rounded p-8 w-full max-w-sm">

        <h1 class="text-2xl font-bold text-gray-800 mb-2">Crear cuenta</h1>
        <p class="text-sm text-gray-500 mb-6">Universidad del Quindio</p>

        <%= if @error do %>
          <div class="bg-red-100 border border-red-300 text-red-700 px-4 py-2 rounded mb-4">
            <%= @error %>
          </div>
        <% end %>

        <%= if @success do %>
          <div class="bg-green-100 border border-green-300 text-green-700 px-4 py-2 rounded mb-4">
            <%= @success %>
            <a href="/login" class="font-bold underline ml-1">Ir al login →</a>
          </div>
        <% end %>

        <form phx-submit="register" class="space-y-4">
          <div>
            <label class="block text-sm mb-1 text-gray-700">Usuario</label>
            <input type="text" name="username" required autofocus
              class="w-full border rounded px-3 py-2" />
          </div>

          <div>
            <label class="block text-sm mb-1 text-gray-700">Contraseña</label>
            <input type="password" name="password" required
              class="w-full border rounded px-3 py-2" />
          </div>

          <div>
            <label class="block text-sm mb-1 text-gray-700">Rol</label>
            <select name="rol" class="w-full border rounded px-3 py-2">
              <option value="cliente">Cliente</option>
              <option value="vendedor">Vendedor</option>
              <option value="arrendador">Arrendador</option>
            </select>
          </div>

          <button type="submit"
            class="w-full bg-green-600 hover:bg-green-700 text-white py-2 rounded">
            Registrarse
          </button>
        </form>

        <p class="text-sm text-center text-gray-500 mt-5">
          ¿Ya tienes cuenta?
          <a href="/login" class="text-blue-600 hover:underline">Inicia sesión</a>
        </p>

      </div>
    </div>
    """
  end

  def render(%{live_action: :login} = assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-100">
      <div class="bg-white shadow rounded p-8 w-full max-w-sm">

        <h1 class="text-2xl font-bold text-gray-800 mb-2">Sistema Inmobiliario</h1>
        <p class="text-sm text-gray-500 mb-6">Universidad del Quindio</p>

        <%= if @error do %>
          <div class="bg-red-100 border border-red-300 text-red-700 px-4 py-2 rounded mb-4">
            <%= @error %>
          </div>
        <% end %>

        <%= if @success do %>
          <div class="bg-green-100 border border-green-300 text-green-700 px-4 py-2 rounded mb-4">
            <%= @success %>
          </div>
        <% end %>

        <form phx-submit="login" class="space-y-4">
          <div>
            <label class="block text-sm mb-1 text-gray-700">Usuario</label>
            <input type="text" name="username" required autofocus
              class="w-full border rounded px-3 py-2" />
          </div>

          <div>
            <label class="block text-sm mb-1 text-gray-700">Contraseña</label>
            <input type="password" name="password" required
              class="w-full border rounded px-3 py-2" />
          </div>

          <button type="submit"
            class="w-full bg-blue-700 hover:bg-blue-800 text-white py-2 rounded">
            Iniciar sesión
          </button>
        </form>

        <p class="text-sm text-center text-gray-500 mt-5">
          ¿No tienes cuenta?
          <a href="/register" class="text-blue-600 hover:underline">Regístrate</a>
        </p>

      </div>
    </div>
    """
  end
end
