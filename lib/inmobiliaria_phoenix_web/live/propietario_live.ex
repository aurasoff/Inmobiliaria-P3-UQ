defmodule InmobiliariaPhoenixWeb.PropietarioLive do
  @moduledoc """
  Panel del vendedor y arrendador.
  Acciones:
    :publicar -> formulario para publicar
    :index    -> lista de propiedades del propietario
    :mensajes -> mensajes recibidos por propiedad
  """

  use InmobiliariaPhoenixWeb, :live_view

  alias Inmobiliaria.{PropertyManager, PropertySupervisor, MessageManager, Location}

  # ── Montaje ────────────────────────────────────────────────────────────────

  @impl true
  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")

    cond do
      current_user == nil ->
        {:ok, redirect(socket, to: "/login")}

      current_user["rol"] == "cliente" ->
        {:ok, redirect(socket, to: "/cliente")}

      true ->
        username = current_user["username"]

        mis_propiedades =
          PropertyManager.load_properties()
          |> Enum.filter(&(&1.propietario == username))

        {:ok,
         assign(socket,
           current_user: current_user,
           mis_propiedades: mis_propiedades,
           ubicaciones: Location.list_locations(),
           error_publicar: nil,
           mensajes_propiedad_id: "",
           mensajes: [],
           error_mensajes: nil
         )}
    end
  end

  # ── Handle params ──────────────────────────────────────────────────────────

  @impl true
  def handle_params(_params, _uri, socket) do
    if socket.assigns[:current_user] do
      username = socket.assigns.current_user["username"]

      mis_propiedades =
        PropertyManager.load_properties()
        |> Enum.filter(&(&1.propietario == username))

      {:noreply,
       assign(socket,
         mis_propiedades: mis_propiedades,
         error_publicar: nil
       )}
    else
      {:noreply, socket}
    end
  end

  # ── Eventos ────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("publicar", params, socket) do
    user = socket.assigns.current_user

    modalidad =
      case user["rol"] do
        "vendedor" -> "venta"
        "arrendador" -> "arriendo"
        _ -> "venta"
      end

    ubicacion = params["ubicacion"] || ""

    if not Location.valid_location?(ubicacion) do
      {:noreply, assign(socket, error_publicar: "Ubicacion '#{ubicacion}' no es valida.")}
    else
      property = %PropertyManager{
        id: PropertyManager.generate_id(),
        tipo: params["tipo"],
        modalidad: modalidad,
        ubicacion: ubicacion,
        precio: parse_int(params["precio"]),
        habitaciones: parse_int(params["habitaciones"]),
        area: parse_float(params["area"]),
        estado: "disponible",
        propietario: user["username"]
      }

      case PropertyManager.save_property(property) do
        :ok ->
          PropertySupervisor.start_property(property)

          mis_propiedades =
            PropertyManager.load_properties()
            |> Enum.filter(&(&1.propietario == user["username"]))

          {:noreply,
           socket
           |> assign(mis_propiedades: mis_propiedades, error_publicar: nil)
           |> put_flash(:info, "Propiedad #{property.id} publicada correctamente.")
           |> push_navigate(to: "/propietario")}

        {:error, _} ->
          {:noreply, assign(socket, error_publicar: "Error al guardar. Intenta de nuevo.")}
      end
    end
  end

  @impl true
  def handle_event("ver_mensajes", %{"id" => propiedad_id}, socket) do
    mensajes = MessageManager.get_messages_for_property(propiedad_id)

    {:noreply,
     assign(socket,
       mensajes: mensajes,
       mensajes_propiedad_id: propiedad_id
     )}
  end

  @impl true
  def handle_event("enviar_mensaje", %{"mensaje" => msg} = params, socket) do
    username = socket.assigns.current_user["username"]
    reply_to = params["reply_to"] || ""
    pid = params["propiedad_id"] || ""
    dest = params["destinatario"] || ""

    cond do
      String.trim(msg) == "" ->
        {:noreply, assign(socket, error_mensajes: "El mensaje no puede estar vacio.")}

      String.trim(dest) != "" ->
        MessageManager.send_message(pid, username, String.trim(dest), msg, reply_to)

        mensajes =
          if pid != "", do: MessageManager.get_messages_for_property(pid), else: @mensajes

        {:noreply,
         socket
         |> assign(mensajes: mensajes)
         |> put_flash(:info, "Mensaje enviado a #{dest}.")}

      true ->
        {:noreply, assign(socket, error_mensajes: "Debes ingresar un destinatario.")}
    end
  end

  @impl true
  def handle_event("cambiar_estado", %{"id" => id, "estado" => nuevo_estado}, socket) do
    username = socket.assigns.current_user["username"]

    # Actualizar en el GenServer si está activo en memoria
    case Registry.lookup(Inmobiliaria.PropertyRegistry, id) do
      [{pid, _}] -> GenServer.call(pid, {:update_state, nuevo_estado})
      [] -> :ok
    end

    # Actualizar en el archivo
    PropertyManager.update_estado(id, nuevo_estado)

    mis_propiedades =
      PropertyManager.load_properties()
      |> Enum.filter(&(&1.propietario == username))

    {:noreply,
     socket
     |> assign(mis_propiedades: mis_propiedades)
     |> put_flash(:info, "Estado actualizado a '#{nuevo_estado}'.")}
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp parse_int(v) do
    case Integer.parse(v || "") do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_float(v) do
    case Float.parse(v || "") do
      {f, _} ->
        f

      :error ->
        case Integer.parse(v || "") do
          {n, _} -> n * 1.0
          :error -> 0.0
        end
    end
  end

  defp formato_precio(precio) do
    precio
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end

  defp color_estado("disponible"), do: "text-green-700"
  defp color_estado("reservada"), do: "text-yellow-600"
  defp color_estado("vendida"), do: "text-gray-400"
  defp color_estado("arrendada"), do: "text-blue-500"
  defp color_estado(_), do: "text-gray-500"

  # ── Render ─────────────────────────────────────────────────────────────────

  @impl true
  def render(%{live_action: :publicar} = assigns) do
    ~H"""
    <div class="bg-white border border-gray-200 rounded p-4 mb-5">
      <h2 class="text-base font-semibold text-gray-800">
        Bienvenido, <%= @current_user["username"] %>
      </h2>
      <p class="text-sm text-gray-500 mt-0.5">
        Como <strong><%= @current_user["rol"] %></strong> puedes publicar propiedades en
        <strong><%= if @current_user["rol"] == "vendedor", do: "venta", else: "arriendo" %></strong>.
      </p>
    </div>

    <%= if @flash["info"] do %>
      <p class="text-sm text-green-700 bg-green-50 border border-green-200 rounded px-3 py-2 mb-4">
        <%= @flash["info"] %>
      </p>
    <% end %>

    <%= if @error_publicar do %>
      <p class="text-sm text-red-600 bg-red-50 border border-red-200 rounded px-3 py-2 mb-4">
        <%= @error_publicar %>
      </p>
    <% end %>

    <form phx-submit="publicar"
      class="bg-white border border-gray-200 rounded p-5 max-w-md space-y-4 text-sm">

      <div>
        <label class="block text-gray-600 mb-1">Tipo de propiedad</label>
        <select name="tipo" required
          class="w-full border border-gray-300 rounded px-3 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="casa">Casa</option>
          <option value="apartamento">Apartamento</option>
          <option value="local">Local comercial</option>
          <option value="finca">Finca</option>
          <option value="lote">Lote</option>
        </select>
      </div>

      <div>
        <label class="block text-gray-600 mb-1">Ubicacion</label>
        <select name="ubicacion" required
          class="w-full border border-gray-300 rounded px-3 py-2 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500">
          <%= for loc <- @ubicaciones do %>
            <option value={loc}><%= loc %></option>
          <% end %>
        </select>
      </div>

      <div>
        <label class="block text-gray-600 mb-1">Precio (COP)</label>
        <input type="number" name="precio" required min="0"
          class="w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="Ej: 300000000" />
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="block text-gray-600 mb-1">Habitaciones</label>
          <input type="number" name="habitaciones" required min="0"
            class="w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Ej: 3" />
        </div>
        <div>
          <label class="block text-gray-600 mb-1">Area (m2)</label>
          <input type="number" name="area" required min="0" step="0.1"
            class="w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Ej: 120.5" />
        </div>
      </div>

      <button type="submit"
        class="w-full bg-blue-700 hover:bg-blue-800 text-white text-sm font-medium py-2 rounded transition">
        Publicar propiedad
      </button>
    </form>

    <p class="text-sm text-gray-500 mt-4">
      <a href="/propietario" class="text-blue-600 hover:underline">
        Ver mis propiedades publicadas
      </a>
    </p>
    """
  end

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold text-gray-800">Mis propiedades</h2>
      <a href="/propietario/publicar"
        class="bg-blue-700 hover:bg-blue-800 text-white text-sm px-4 py-1.5 rounded transition">
        Publicar nueva
      </a>
    </div>

    <%= if @flash["info"] do %>
      <p class="text-sm text-green-700 bg-green-50 border border-green-200 rounded px-3 py-2 mb-4">
        <%= @flash["info"] %>
      </p>
    <% end %>

    <%= if @mis_propiedades == [] do %>
      <div class="bg-white border border-gray-200 rounded p-8 text-center">
        <p class="text-gray-500 text-sm mb-3">No tienes propiedades publicadas.</p>
        <a href="/propietario/publicar" class="text-blue-600 hover:underline text-sm">
          Publica tu primera propiedad
        </a>
      </div>
    <% else %>
      <div class="overflow-x-auto">
        <table class="w-full text-sm border border-gray-200 rounded bg-white">
          <thead class="bg-gray-50 text-gray-600 text-left">
            <tr>
              <th class="px-4 py-2 font-medium">ID</th>
              <th class="px-4 py-2 font-medium">Tipo</th>
              <th class="px-4 py-2 font-medium">Modalidad</th>
              <th class="px-4 py-2 font-medium">Ubicacion</th>
              <th class="px-4 py-2 font-medium">Precio</th>
              <th class="px-4 py-2 font-medium">Estado</th>
              <th class="px-4 py-2 font-medium">Mensajes</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for p <- @mis_propiedades do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-2 text-gray-400 text-xs"><%= p.id %></td>
                <td class="px-4 py-2 capitalize"><%= p.tipo %></td>
                <td class="px-4 py-2 capitalize"><%= p.modalidad %></td>
                <td class="px-4 py-2"><%= p.ubicacion %></td>
                <td class="px-4 py-2 font-medium">$<%= formato_precio(p.precio) %></td>
                <td class="px-4 py-2">
    <form phx-change="cambiar_estado">
    <input type="hidden" name="id" value={p.id} />
    <select
      name="estado"
      class={"text-xs border rounded px-2 py-1 font-medium bg-white #{color_estado(p.estado)}"}
    >
      <option value="disponible" selected={p.estado == "disponible"}>Disponible</option>
      <option value="reservada"  selected={p.estado == "reservada"}>Reservada</option>
      <option value="vendida"    selected={p.estado == "vendida"}>Vendida</option>
      <option value="arrendada"  selected={p.estado == "arrendada"}>Arrendada</option>
    </select>
    </form>
    </td>
                <td class="px-4 py-2">
                  <a href="/propietario/mensajes"
                    phx-click="ver_mensajes" phx-value-id={p.id}
                    class="text-xs text-blue-600 hover:underline">
                    Ver mensajes
                  </a>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <p class="text-xs text-gray-400 mt-2">
        <%= length(@mis_propiedades) %> propiedad(es) en total
      </p>
    <% end %>
    """
  end

  @impl true
  def render(%{live_action: :mensajes} = assigns) do
    ~H"""
    <h2 class="text-lg font-semibold text-gray-800 mb-4">Mensajes</h2>

    <%= if @flash["info"] do %>
      <p class="text-sm text-green-700 bg-green-50 border border-green-200 rounded px-3 py-2 mb-4">
        <%= @flash["info"] %>
      </p>
    <% end %>

    <%# Formulario para enviar mensaje nuevo a cualquier usuario %>
    <form phx-submit="enviar_mensaje"
      class="bg-white border border-gray-200 rounded p-5 max-w-md space-y-4 text-sm mb-6">
      <div>
        <label class="block text-gray-600 mb-1">Destinatario (usuario)</label>
        <input type="text" name="destinatario" required
          class="w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="Ej: cliente, maria, etc." />
      </div>
      <div>
        <label class="block text-gray-600 mb-1">ID de propiedad (opcional)</label>
        <input type="text" name="propiedad_id"
          class="w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="Ej: prop12345" />
      </div>
      <div>
        <label class="block text-gray-600 mb-1">Mensaje</label>
        <textarea name="mensaje" rows="2" required
          class="w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="Escribe tu mensaje..."></textarea>
      </div>
      <input type="hidden" name="reply_to" value="" />
      <button type="submit"
        class="bg-blue-700 hover:bg-blue-800 text-white text-sm px-4 py-2 rounded transition">
        Enviar mensaje
      </button>
    </form>

    <%# Selector de propiedad para ver mensajes recibidos %>
    <%= if @mis_propiedades != [] do %>
      <h3 class="text-sm font-semibold text-gray-700 mb-2">Mensajes por propiedad</h3>
      <div class="flex flex-wrap gap-2 mb-4">
        <%= for p <- @mis_propiedades do %>
          <button phx-click="ver_mensajes" phx-value-id={p.id}
            class={[
              "text-xs px-3 py-1.5 rounded border transition",
              @mensajes_propiedad_id == p.id && "bg-blue-700 text-white border-blue-700",
              @mensajes_propiedad_id != p.id && "border-gray-300 text-gray-600 hover:border-blue-400"
            ]}>
            <%= p.id %> (<%= p.tipo %>)
          </button>
        <% end %>
      </div>

      <%= if @mensajes_propiedad_id != "" do %>
        <%= if @mensajes == [] do %>
          <p class="text-sm text-gray-500 mb-4">Sin mensajes para esta propiedad.</p>
        <% else %>
          <div class="space-y-3 max-w-lg mb-6">
            <%= for m <- @mensajes do %>
              <div class={[
                "border rounded p-3 text-sm",
                m.sender == @current_user["username"] && "bg-blue-50 border-blue-200 ml-8",
                m.sender != @current_user["username"] && "bg-white border-gray-200"
              ]}>
                <div class="flex justify-between text-xs text-gray-400 mb-1">
                  <span class="font-medium text-gray-700">
                    <%= if m.sender == @current_user["username"] do %>
                      Tú → <%= m.recipient %>
                    <% else %>
                      <%= m.sender %> → Ti
                    <% end %>
                  </span>
                  <span><%= String.slice(m.timestamp, 0, 16) |> String.replace("T", " ") %></span>
                </div>
                <p class="text-gray-700 mb-2"><%= m.message %></p>

                <%= if m.recipient == @current_user["username"] do %>
                  <form phx-submit="enviar_mensaje" class="mt-2 flex gap-2">
                    <input type="hidden" name="destinatario" value={m.sender} />
                    <input type="hidden" name="propiedad_id" value={m.property_id} />
                    <input type="hidden" name="reply_to" value={m.timestamp} />
                    <input type="text" name="mensaje" required placeholder={"Responder a #{m.sender}..."}
                      class="flex-1 border border-gray-300 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-blue-500" />
                    <button type="submit"
                      class="bg-blue-700 hover:bg-blue-800 text-white text-xs px-3 py-1 rounded transition">
                      Responder
                    </button>
                  </form>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      <% end %>
    <% end %>

    <%# Historial completo del propietario %>
    <h3 class="text-sm font-semibold text-gray-700 mb-2">Todos mis mensajes</h3>
    <% yo = @current_user["username"] %>
    <% todos = Inmobiliaria.MessageManager.get_messages_for_user(yo) %>

    <%= if todos == [] do %>
      <p class="text-sm text-gray-500">No tienes mensajes aún.</p>
    <% else %>
      <div class="space-y-3 max-w-lg">
        <%= for m <- todos do %>
          <div class={[
            "border rounded p-3 text-sm",
            m.sender == yo && "bg-blue-50 border-blue-200",
            m.sender != yo && "bg-white border-gray-200"
          ]}>
            <div class="flex justify-between text-xs text-gray-400 mb-1">
              <span class="font-medium text-gray-700">
                <%= if m.sender == yo do %>
                  Tú → <%= m.recipient %>
                <% else %>
                  <%= m.sender %> → Ti
                <% end %>
              </span>
              <span><%= String.slice(m.timestamp, 0, 16) |> String.replace("T", " ") %></span>
            </div>
            <p class="text-gray-700 mb-1"><%= m.message %></p>
            <%= if m.property_id != "" do %>
              <p class="text-xs text-gray-400 mb-1">Propiedad: <%= m.property_id %></p>
            <% end %>

            <%= if m.recipient == yo do %>
              <form phx-submit="enviar_mensaje" class="mt-2 flex gap-2">
                <input type="hidden" name="destinatario" value={m.sender} />
                <input type="hidden" name="propiedad_id" value={m.property_id} />
                <input type="hidden" name="reply_to" value={m.timestamp} />
                <input type="text" name="mensaje" required placeholder={"Responder a #{m.sender}..."}
                  class="flex-1 border border-gray-300 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-blue-500" />
                <button type="submit"
                  class="bg-blue-700 hover:bg-blue-800 text-white text-xs px-3 py-1 rounded transition">
                  Responder
                </button>
              </form>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end
end
