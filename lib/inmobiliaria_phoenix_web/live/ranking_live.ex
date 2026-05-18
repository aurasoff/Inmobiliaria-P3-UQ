defmodule InmobiliariaPhoenixWeb.RankingLive do
  @moduledoc """
  Pagina de rankings del sistema.
  Muestra cuatro tablas:
    - Ranking general: todos los usuarios ordenados por puntaje acumulado
    - Compradores: clientes con mas compras realizadas
    - Vendedores: vendedores con mas propiedades vendidas
    - Arrendadores: arrendadores con mas propiedades arrendadas

  Accesible para cualquier usuario autenticado.
  Si no hay sesion activa, redirige al login.
  """

  use InmobiliariaPhoenixWeb, :live_view

  alias Inmobiliaria.{UserManager, ResultsLogger}

  # ── Montaje ────────────────────────────────────────────────────────────────

  @impl true
  def mount(_params, session, socket) do
    case session["current_user"] do
      nil ->
        {:ok, push_navigate(socket, to: "/login")}

      user_map ->
        {:ok,
         assign(socket,
           current_user: user_map,
           # Cada ranking se carga una sola vez al montar la pagina
           ranking_general:     UserManager.get_ranking(),
           ranking_compradores: ResultsLogger.get_ranking_compradores(),
           ranking_vendedores:  ResultsLogger.get_ranking_vendedores(),
           ranking_arrendadores: ResultsLogger.get_ranking_arrendadores(),
           # Pestana activa por defecto
           tab_activa: "general"
         )}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # ── Eventos ────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("cambiar_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, tab_activa: tab)}
  end

  # ── Render ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <h2 class="text-lg font-semibold text-gray-800 mb-4">Rankings</h2>

    <%# Barra de pestanas %>
    <div class="flex gap-1 mb-5 border-b border-gray-200">
      <%= for {tab, label} <- [
        {"general",     "General"},
        {"compradores", "Compradores"},
        {"vendedores",  "Vendedores"},
        {"arrendadores","Arrendadores"}
      ] do %>
        <button phx-click="cambiar_tab" phx-value-tab={tab}
          class={[
            "px-4 py-2 text-sm border-b-2 transition",
            @tab_activa == tab &&
              "border-pink-700 text-pink-700 font-medium",
            @tab_activa != tab &&
              "border-transparent text-gray-500 hover:text-gray-700"
          ]}>
          <%= label %>
        </button>
      <% end %>
    </div>

    <%# Ranking general: ordenado por puntaje total %>
    <%= if @tab_activa == "general" do %>
      <%= if @ranking_general == [] do %>
        <p class="text-sm text-gray-500">No hay usuarios registrados aun.</p>
      <% else %>
        <table class="w-full text-sm border border-gray-200 rounded max-w-lg">
          <thead class="bg-gray-50 text-gray-600 text-left">
            <tr>
              <th class="px-4 py-2 font-medium w-10">#</th>
              <th class="px-4 py-2 font-medium">Usuario</th>
              <th class="px-4 py-2 font-medium">Rol</th>
              <th class="px-4 py-2 font-medium text-right">Puntaje</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for {{username, rol, puntaje}, i} <- Enum.with_index(@ranking_general, 1) do %>
              <tr class={if i <= 3, do: "bg-yellow-50", else: "hover:bg-gray-50"}>
                <td class="px-4 py-2 text-gray-400"><%= i %></td>
                <td class="px-4 py-2 font-medium"><%= username %></td>
                <td class="px-4 py-2 text-gray-500 capitalize"><%= rol %></td>
                <td class="px-4 py-2 text-right font-semibold text-blue-700"><%= puntaje %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    <% end %>

    <%# Rankings por operacion: compradores, vendedores, arrendadores %>
    <%= if @tab_activa in ["compradores", "vendedores", "arrendadores"] do %>
      <% datos = case @tab_activa do
        "compradores"  -> @ranking_compradores
        "vendedores"   -> @ranking_vendedores
        "arrendadores" -> @ranking_arrendadores
      end %>

      <%= if datos == [] do %>
        <p class="text-sm text-gray-500">Sin operaciones registradas aun.</p>
      <% else %>
        <table class="w-full text-sm border border-pink-200 rounded max-w-lg">
          <thead class="bg-gray-50 text-gray-600 text-left">
            <tr>
              <th class="px-4 py-2 font-medium w-10">#</th>
              <th class="px-4 py-2 font-medium">Usuario</th>
              <th class="px-4 py-2 font-medium text-right">Operaciones</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for {{username, count}, i} <- Enum.with_index(datos, 1) do %>
              <tr class={if i <= 3, do: "bg-yellow-50", else: "hover:bg-gray-50"}>
                <td class="px-4 py-2 text-gray-400"><%= i %></td>
                <td class="px-4 py-2 font-medium"><%= username %></td>
                <td class="px-4 py-2 text-right font-semibold text-blue-700"><%= count %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    <% end %>
    """
  end
end
