defmodule InmobiliariaPhoenixWeb.ChatLive do
  use InmobiliariaPhoenixWeb, :live_view

  alias Inmobiliaria.{MessageManager, UsuariosStore}

  @impl true
  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")

    if current_user == nil do
      {:ok, redirect(socket, to: "/login")}
    else
      yo = current_user["username"]

      # Obtener todas las conversaciones del usuario
      conversaciones = obtener_conversaciones(yo)

      {:ok,
       assign(socket,
         current_user: current_user,
         conversaciones: conversaciones,
         conversacion_activa: nil,
         mensajes: [],
         mensaje_texto: "",
         error: nil
       )}
    end
  end

  @impl true
  def handle_params(%{"username" => otro_username}, _uri, socket) do
    yo = socket.assigns.current_user["username"]
    mensajes = MessageManager.get_conversation(yo, otro_username)

    {:noreply,
     assign(socket,
       conversacion_activa: otro_username,
       mensajes: mensajes
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, conversacion_activa: nil, mensajes: [])}
  end

  @impl true
  def handle_event("enviar", %{"mensaje" => msg}, socket) do
    yo = socket.assigns.current_user["username"]
    dest = socket.assigns.conversacion_activa

    if String.trim(msg) == "" do
      {:noreply, socket}
    else
      MessageManager.send_message("", yo, dest, msg)

      mensajes = MessageManager.get_conversation(yo, dest)
      conversaciones = obtener_conversaciones(yo)

      {:noreply,
       assign(socket,
         mensajes: mensajes,
         conversaciones: conversaciones,
         mensaje_texto: ""
       )}
    end
  end

  @impl true
  def handle_event("nueva_conversacion", %{"destinatario" => dest}, socket) do
    yo = socket.assigns.current_user["username"]
    dest = String.trim(dest)

    cond do
      dest == "" ->
        {:noreply, assign(socket, error: "Escribe un nombre de usuario.")}

      dest == yo ->
        {:noreply, assign(socket, error: "No puedes enviarte mensajes a ti mismo.")}

      not InmobiliariaPhoenix.UsuariosStore.existe?(dest) ->
        {:noreply, assign(socket, error: "El usuario '#{dest}' no existe.")}

      true ->
        {:noreply,
         socket
         |> assign(error: nil)
         |> push_navigate(to: "/chat/#{dest}")}
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp obtener_conversaciones(username) do
    MessageManager.get_messages_for_user(username)
    |> Enum.map(fn m ->
      if m.sender == username, do: m.recipient, else: m.sender
    end)
    |> Enum.uniq()
  end

  # ── Render ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-[75vh] bg-white border border-gray-200 rounded overflow-hidden">

      <%# Panel izquierdo — conversaciones %>
      <div class="w-72 border-r border-gray-200 flex flex-col">

        <div class="bg-pink-500 text-white p-4">
          <h2 class="font-semibold text-base"> Conversaciones</h2>
          <p class="text-xs text-indigo-200 mt-0.5">
            <%= @current_user["username"] %> · <%= @current_user["rol"] %>
          </p>
        </div>

        <%# Nueva conversacion %>
        <form phx-submit="nueva_conversacion" class="p-3 border-b border-gray-100">
          <div class="flex gap-2">
            <input type="text" name="destinatario" placeholder="Usuario..."
              class="flex-1 text-xs border border-gray-300 rounded px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-indigo-500" />
            <button type="submit"
              class="bg-pink-400 hover:bg-pink-700 text-white text-xs px-2 py-1.5 rounded transition">
              +
            </button>
          </div>
          <%= if @error do %>
            <p class="text-xs text-red-500 mt-1"><%= @error %></p>
          <% end %>
        </form>

        <%# Lista de conversaciones %>
        <div class="flex-1 overflow-y-auto">
          <%= if @conversaciones == [] do %>
            <p class="text-xs text-gray-400 p-4">Sin conversaciones aún.</p>
          <% else %>
            <%= for otro <- @conversaciones do %>
              <a href={"/chat/#{otro}"}
                class={[
                  "block px-4 py-3 border-b border-gray-100 hover:bg-indigo-50 transition cursor-pointer",
                  @conversacion_activa == otro && "bg-indigo-100 border-l-4 border-l-indigo-600"
                ]}>
                <p class="text-sm font-medium text-gray-800"><%= otro %></p>
              </a>
            <% end %>
          <% end %>
        </div>
      </div>

      <%# Panel derecho — mensajes %>
      <div class="flex-1 flex flex-col">

        <%= if @conversacion_activa do %>

          <%# Header %>
          <div class="border-b border-gray-200 px-5 py-3 flex items-center gap-3">
            <div class="w-8 h-8 rounded-full bg-indigo-100 flex items-center justify-center text-sm font-bold text-indigo-600">
              <%= String.first(@conversacion_activa) |> String.upcase() %>
            </div>
            <div>
              <p class="text-sm font-semibold text-gray-800"><%= @conversacion_activa %></p>
            </div>
          </div>

          <%# Mensajes %>
          <div class="flex-1 overflow-y-auto p-4 space-y-3">
            <%= if @mensajes == [] do %>
              <p class="text-sm text-gray-400 text-center mt-10">
                No hay mensajes aún. ¡Sé el primero en escribir!
              </p>
            <% else %>
              <%= for m <- @mensajes do %>
                <div class={[
                  "flex",
                  m.sender == @current_user["username"] && "justify-end",
                  m.sender != @current_user["username"] && "justify-start"
                ]}>
                  <div class={[
                    "max-w-xs px-4 py-2 rounded-2xl text-sm",
                    m.sender == @current_user["username"] &&
                      "bg-indigo-600 text-white rounded-br-none",
                    m.sender != @current_user["username"] &&
                      "bg-gray-100 text-gray-800 rounded-bl-none"
                  ]}>
                    <p><%= m.message %></p>
                    <p class={[
                      "text-xs mt-1",
                      m.sender == @current_user["username"] && "text-indigo-200",
                      m.sender != @current_user["username"] && "text-gray-400"
                    ]}>
                      <%= String.slice(m.timestamp, 11, 5) %>
                    </p>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <%# Input de mensaje %>
          <form phx-submit="enviar" class="border-t border-gray-200 px-4 py-3 flex gap-3">
            <input
              type="text"
              name="mensaje"
              value={@mensaje_texto}
              placeholder={"Escribe un mensaje a #{@conversacion_activa}..."}
              autocomplete="off"
              class="flex-1 border border-gray-300 rounded-full px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <button type="submit"
              class="bg-pink-600 hover:bg-pink-700 text-white text-sm px-5 py-2 rounded-full transition">
              Enviar
            </button>
          </form>

        <% else %>

          <div class="flex-1 flex items-center justify-center">
            <div class="text-center">
              <p class="text-4xl mb-3"></p>
              <p class="text-gray-500 text-sm">
                Selecciona una conversación o inicia una nueva
              </p>
            </div>
          </div>

        <% end %>
      </div>
    </div>
    """
  end
end
