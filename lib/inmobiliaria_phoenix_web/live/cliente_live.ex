defmodule InmobiliariaPhoenixWeb.ClienteLive do
  @moduledoc """
  Panel del cliente.
  Acciones:
    :index    -> propiedades disponibles con bienvenida
    :buscar   -> misma lista pero con filtros aplicados
    :comprar  -> detalle de una propiedad para comprar o arrendar
    :mensajes -> enviar mensaje a un propietario
  """

  use InmobiliariaPhoenixWeb, :live_view

  alias Inmobiliaria.{PropertyManager, MessageManager}

  # ── Montaje ────────────────────────────────────────────────────────────────

  @impl true
  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user")

    cond do
      current_user == nil ->
        {:ok, redirect(socket, to: "/login")}

      current_user["rol"] != "cliente" ->
        {:ok, redirect(socket, to: "/login")}

      true ->
        {:ok,
         assign(socket,
           current_user: current_user,
           properties: PropertyManager.list_available(),
           filtro_tipo: "",
           filtro_modalidad: "",
           filtro_ubicacion: "",
           filtro_precio_min: "",
           filtro_precio_max: "",
           propiedad_seleccionada: nil,
           resultado_operacion: nil,
           mensaje_propiedad_id: "",
           mensaje_texto: "",
           mensajes_usuario: [],
           error: nil
         )}
    end
  end

  # ── Handle params ──────────────────────────────────────────────────────────

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    propiedad =
      case PropertyManager.find_property(id) do
        {:ok, p} -> p
        _ -> nil
      end

    {:noreply, assign(socket, propiedad_seleccionada: propiedad)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # ── Eventos ────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("buscar", params, socket) do
    filtros =
      %{}
      |> put_si_no_vacio(:tipo, params["tipo"])
      |> put_si_no_vacio(:modalidad, params["modalidad"])
      |> put_si_no_vacio(:ubicacion, params["ubicacion"])
      |> put_si_no_vacio(:precio_min, params["precio_min"])
      |> put_si_no_vacio(:precio_max, params["precio_max"])

    {:noreply,
     assign(socket,
       properties: PropertyManager.list_available(filtros),
       filtro_tipo: params["tipo"] || "",
       filtro_modalidad: params["modalidad"] || "",
       filtro_ubicacion: params["ubicacion"] || "",
       filtro_precio_min: params["precio_min"] || "",
       filtro_precio_max: params["precio_max"] || ""
     )}
  end

  @impl true
  def handle_event("limpiar_filtros", _params, socket) do
    {:noreply,
     assign(socket,
       properties: PropertyManager.list_available(),
       filtro_tipo: "",
       filtro_modalidad: "",
       filtro_ubicacion: "",
       filtro_precio_min: "",
       filtro_precio_max: ""
     )}
  end

  @impl true
  def handle_event("comprar", _params, socket) do
    ejecutar_operacion(socket, :buy, "compra")
  end

  @impl true
  def handle_event("arrendar", _params, socket) do
    ejecutar_operacion(socket, :rent, "arriendo")
  end

  @impl true
  def handle_event("enviar_mensaje", %{"mensaje" => msg} = params, socket) do
    username = socket.assigns.current_user["username"]
    reply_to = params["reply_to"] || ""
    pid = params["propiedad_id"] || ""
    dest = params["destinatario"] || ""

    cond do
      String.trim(msg) == "" ->
        {:noreply, assign(socket, error: "El mensaje no puede estar vacio.")}

      # Si viene destinatario directo (respuesta o mensaje libre)
      String.trim(dest) != "" ->
        MessageManager.send_message(pid, username, String.trim(dest), msg, reply_to)

        {:noreply,
         socket
         |> assign(mensaje_propiedad_id: "", mensaje_texto: "", error: nil)
         |> put_flash(:info, "Mensaje enviado a #{dest}.")}

      # Si viene propiedad_id, buscar propietario
      String.trim(pid) != "" ->
        case PropertyManager.find_property(String.trim(pid)) do
          {:error, :not_found} ->
            {:noreply, assign(socket, error: "Propiedad '#{pid}' no encontrada.")}

          {:ok, property} ->
            MessageManager.send_message(pid, username, property.propietario, msg, reply_to)

            {:noreply,
             socket
             |> assign(mensaje_propiedad_id: "", mensaje_texto: "", error: nil)
             |> put_flash(:info, "Mensaje enviado a #{property.propietario}.")}
        end

      true ->
        {:noreply, assign(socket, error: "Debes ingresar una propiedad o un destinatario.")}
    end
  end

  # ── Lógica de operación ────────────────────────────────────────────────────

  defp ejecutar_operacion(socket, tipo_op, nombre_op) do
    property = socket.assigns.propiedad_seleccionada
    username = socket.assigns.current_user["username"]

    case Registry.lookup(Inmobiliaria.PropertyRegistry, property.id) do
      [] ->
        {:noreply,
         assign(socket,
           resultado_operacion: {:error, "La propiedad no esta activa en el sistema."}
         )}

      [{pid, _}] ->
        msg_genserver = if tipo_op == :buy, do: {:buy, username}, else: {:rent, username}

        case GenServer.call(pid, msg_genserver) do
          {:ok, _} ->
            {:noreply,
             assign(socket,
               resultado_operacion:
                 {:ok,
                  "#{String.capitalize(nombre_op)} completada. Se sumaron 10 puntos a tu cuenta."},
               propiedad_seleccionada: %{property | estado: "no disponible"}
             )}

          {:error, :not_available} ->
            {:noreply,
             assign(socket,
               resultado_operacion: {:error, "La propiedad ya no esta disponible."}
             )}
        end
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp put_si_no_vacio(map, _key, nil), do: map
  defp put_si_no_vacio(map, _key, ""), do: map
  defp put_si_no_vacio(map, key, val), do: Map.put(map, key, val)

  defp formato_precio(precio) do
    precio
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end

  # ── Render ─────────────────────────────────────────────────────────────────

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <div class="bg-white border border-gray-200 rounded p-4 mb-5">
      <h2 class="text-base font-semibold text-gray-800">
        Bienvenido, <%= @current_user["username"] %>
      </h2>
      <p class="text-sm text-gray-500 mt-0.5">
        Estas son las propiedades disponibles para compra y arriendo.
        Haz clic en "Ver" para ver el detalle y realizar la operacion.
      </p>
    </div>

    <div class="flex gap-2 mb-4 text-sm">
      <button phx-click="limpiar_filtros"
        class={["px-3 py-1.5 rounded border transition",
          @filtro_modalidad == "" && "bg-blue-700 text-white border-blue-700",
          @filtro_modalidad != "" && "border-gray-300 text-gray-600 hover:border-blue-400"]}>
        Todas
      </button>

      <button phx-click="buscar" phx-value-modalidad="venta"
        class={["px-3 py-1.5 rounded border transition",
          @filtro_modalidad == "venta" && "bg-blue-700 text-white border-blue-700",
          @filtro_modalidad != "venta" && "border-gray-300 text-gray-600 hover:border-blue-400"]}>
        En venta
      </button>

      <button phx-click="buscar" phx-value-modalidad="arriendo"
        class={["px-3 py-1.5 rounded border transition",
          @filtro_modalidad == "arriendo" && "bg-blue-700 text-white border-blue-700",
          @filtro_modalidad != "arriendo" && "border-gray-300 text-gray-600 hover:border-blue-400"]}>
        En arriendo
      </button>

      <a href="/cliente/buscar"
        class="ml-auto px-3 py-1.5 rounded border border-gray-300 text-gray-600 hover:border-blue-400 transition">
        Busqueda avanzada
      </a>
    </div>

    <%= if @properties == [] do %>
      <div class="bg-white border border-gray-200 rounded p-8 text-center">
        <p class="text-gray-500 text-sm">No hay propiedades disponibles en este momento.</p>
      </div>
    <% else %>
      <div class="overflow-x-auto">
        <table class="w-full text-sm border border-gray-200 rounded bg-white">
          <thead class="bg-gray-50 text-gray-600 text-left">
            <tr>
              <th class="px-4 py-2 font-medium">Tipo</th>
              <th class="px-4 py-2 font-medium">Modalidad</th>
              <th class="px-4 py-2 font-medium">Ubicacion</th>
              <th class="px-4 py-2 font-medium">Precio</th>
              <th class="px-4 py-2 font-medium">Hab.</th>
              <th class="px-4 py-2 font-medium">Area m2</th>
              <th class="px-4 py-2 font-medium">Propietario</th>
              <th class="px-4 py-2 font-medium"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for p <- @properties do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-2 capitalize"><%= p.tipo %></td>
                <td class="px-4 py-2">
                  <span class={["text-xs px-2 py-0.5 rounded font-medium capitalize",
                    p.modalidad == "venta"    && "bg-blue-100 text-blue-700",
                    p.modalidad == "arriendo" && "bg-green-100 text-green-700"]}>
                    <%= p.modalidad %>
                  </span>
                </td>
                <td class="px-4 py-2"><%= p.ubicacion %></td>
                <td class="px-4 py-2 font-medium">$<%= formato_precio(p.precio) %></td>
                <td class="px-4 py-2"><%= p.habitaciones %></td>
                <td class="px-4 py-2"><%= p.area %></td>
                <td class="px-4 py-2 text-gray-500"><%= p.propietario %></td>
                <td class="px-4 py-2">
                  <a href={"/cliente/comprar/#{p.id}"}
                    class="text-xs text-blue-600 hover:underline whitespace-nowrap">
                    Ver y <%= if p.modalidad == "venta", do: "comprar", else: "arrendar" %>
                  </a>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <p class="text-xs text-gray-400 mt-2"><%= length(@properties) %> propiedad(es) disponible(s)</p>
    <% end %>
    """
  end

  @impl true
  def render(%{live_action: :buscar} = assigns) do
    ~H"""
    <h2 class="text-lg font-semibold text-gray-800 mb-4">Busqueda avanzada</h2>

    <form phx-submit="buscar"
      class="bg-white border border-gray-200 rounded p-4 mb-5 grid grid-cols-2 gap-3 text-sm">

      <div>
        <label class="block text-gray-600 mb-1">Tipo</label>
        <select name="tipo"
          class="w-full border border-gray-300 rounded px-2 py-1.5 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">Todos</option>
          <option value="casa"        selected={@filtro_tipo == "casa"}>Casa</option>
          <option value="apartamento" selected={@filtro_tipo == "apartamento"}>Apartamento</option>
          <option value="local"       selected={@filtro_tipo == "local"}>Local</option>
          <option value="finca"       selected={@filtro_tipo == "finca"}>Finca</option>
          <option value="lote"        selected={@filtro_tipo == "lote"}>Lote</option>
        </select>
      </div>

      <div>
        <label class="block text-gray-600 mb-1">Modalidad</label>
        <select name="modalidad"
          class="w-full border border-gray-300 rounded px-2 py-1.5 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">Venta y arriendo</option>
          <option value="venta"    selected={@filtro_modalidad == "venta"}>Solo venta</option>
          <option value="arriendo" selected={@filtro_modalidad == "arriendo"}>Solo arriendo</option>
        </select>
      </div>

      <div>
        <label class="block text-gray-600 mb-1">Ubicacion</label>
        <select name="ubicacion"
          class="w-full border border-gray-300 rounded px-2 py-1.5 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">Todas</option>
          <option value="Armenia"    selected={@filtro_ubicacion == "Armenia"}>Armenia</option>
          <option value="Calarca"    selected={@filtro_ubicacion == "Calarca"}>Calarca</option>
          <option value="Montenegro" selected={@filtro_ubicacion == "Montenegro"}>Montenegro</option>
          <option value="Quimbaya"   selected={@filtro_ubicacion == "Quimbaya"}>Quimbaya</option>
          <option value="La Tebaida" selected={@filtro_ubicacion == "La Tebaida"}>La Tebaida</option>
        </select>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <div>
          <label class="block text-gray-600 mb-1">Precio minimo</label>
          <input type="number" name="precio_min" value={@filtro_precio_min} min="0"
            class="w-full border border-gray-300 rounded px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="0" />
        </div>
        <div>
          <label class="block text-gray-600 mb-1">Precio maximo</label>
          <input type="number" name="precio_max" value={@filtro_precio_max} min="0"
            class="w-full border border-gray-300 rounded px-2 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Sin limite" />
        </div>
      </div>

      <div class="col-span-2 flex gap-2">
        <button type="submit"
          class="bg-blue-700 hover:bg-blue-800 text-white text-sm px-4 py-1.5 rounded transition">
          Buscar
        </button>
        <button type="button" phx-click="limpiar_filtros"
          class="border border-gray-300 text-gray-600 hover:border-gray-400 text-sm px-3 py-1.5 rounded transition">
          Limpiar
        </button>
        <a href="/cliente"
          class="ml-auto text-sm text-gray-500 hover:underline self-center">
          Volver
        </a>
      </div>
    </form>

    <%= if @properties == [] do %>
      <p class="text-sm text-gray-500">No hay propiedades con esos criterios.</p>
    <% else %>
      <div class="overflow-x-auto">
        <table class="w-full text-sm border border-gray-200 rounded bg-white">
          <thead class="bg-gray-50 text-gray-600 text-left">
            <tr>
              <th class="px-4 py-2 font-medium">Tipo</th>
              <th class="px-4 py-2 font-medium">Modalidad</th>
              <th class="px-4 py-2 font-medium">Ubicacion</th>
              <th class="px-4 py-2 font-medium">Precio</th>
              <th class="px-4 py-2 font-medium">Hab.</th>
              <th class="px-4 py-2 font-medium">Area m2</th>
              <th class="px-4 py-2 font-medium"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for p <- @properties do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-2 capitalize"><%= p.tipo %></td>
                <td class="px-4 py-2">
                  <span class={["text-xs px-2 py-0.5 rounded font-medium capitalize",
                    p.modalidad == "venta"    && "bg-blue-100 text-blue-700",
                    p.modalidad == "arriendo" && "bg-green-100 text-green-700"]}>
                    <%= p.modalidad %>
                  </span>
                </td>
                <td class="px-4 py-2"><%= p.ubicacion %></td>
                <td class="px-4 py-2 font-medium">$<%= formato_precio(p.precio) %></td>
                <td class="px-4 py-2"><%= p.habitaciones %></td>
                <td class="px-4 py-2"><%= p.area %></td>
                <td class="px-4 py-2">
                  <a href={"/cliente/comprar/#{p.id}"}
                    class="text-xs text-blue-600 hover:underline">Ver</a>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <p class="text-xs text-gray-400 mt-2"><%= length(@properties) %> resultado(s)</p>
    <% end %>
    """
  end

  @impl true
  def render(%{live_action: :comprar} = assigns) do
    ~H"""
    <a href="/cliente" class="text-sm text-blue-600 hover:underline">Volver al listado</a>

    <%= if @propiedad_seleccionada do %>
      <% p = @propiedad_seleccionada %>
      <div class="bg-white border border-gray-200 rounded mt-4 p-6 max-w-md">
        <h2 class="text-base font-semibold text-gray-800 mb-1 capitalize">
          <%= p.tipo %> en <%= p.modalidad %>
        </h2>
        <p class="text-xs text-gray-400 mb-4">ID: <%= p.id %></p>

        <table class="text-sm w-full mb-5">
          <tbody class="divide-y divide-gray-100">
            <tr>
              <td class="py-1.5 text-gray-500 w-28">Ubicacion</td>
              <td class="py-1.5"><%= p.ubicacion %></td>
            </tr>
            <tr>
              <td class="py-1.5 text-gray-500">Precio</td>
              <td class="py-1.5 font-semibold">$<%= formato_precio(p.precio) %></td>
            </tr>
            <tr>
              <td class="py-1.5 text-gray-500">Habitaciones</td>
              <td class="py-1.5"><%= p.habitaciones %></td>
            </tr>
            <tr>
              <td class="py-1.5 text-gray-500">Area</td>
              <td class="py-1.5"><%= p.area %> m2</td>
            </tr>
            <tr>
              <td class="py-1.5 text-gray-500">Propietario</td>
              <td class="py-1.5"><%= p.propietario %></td>
            </tr>
            <tr>
              <td class="py-1.5 text-gray-500">Estado</td>
              <td class="py-1.5 capitalize"><%= p.estado %></td>
            </tr>
          </tbody>
        </table>

        <%= if @resultado_operacion do %>
          <% {tipo, msg} = @resultado_operacion %>
          <p class={["text-sm rounded px-3 py-2 mb-4",
            tipo == :ok    && "bg-green-50 border border-green-200 text-green-700",
            tipo == :error && "bg-red-50 border border-red-200 text-red-600"]}>
            <%= msg %>
          </p>
        <% end %>

        <%= if p.estado == "disponible" && @resultado_operacion == nil do %>
          <%= if p.modalidad == "venta" do %>
            <button phx-click="comprar"
              class="bg-blue-700 hover:bg-blue-800 text-white text-sm px-5 py-2 rounded transition">
              Confirmar compra
            </button>
          <% else %>
            <button phx-click="arrendar"
              class="bg-blue-700 hover:bg-blue-800 text-white text-sm px-5 py-2 rounded transition">
              Confirmar arriendo
            </button>
          <% end %>
        <% end %>
      </div>
    <% else %>
      <p class="text-sm text-gray-500 mt-4">Propiedad no encontrada.</p>
    <% end %>
    """
  end

  @impl true
  def render(%{live_action: :mensajes} = assigns) do
  ~H"""
  <h2 class="text-lg font-semibold text-gray-800 mb-4">Mis mensajes</h2>

  <%= if @error do %>
    <p class="text-sm text-red-600 bg-red-50 border border-red-200 rounded px-3 py-2 mb-4">
      <%= @error %>
    </p>
  <% end %>

  <%= if @flash["info"] do %>
    <p class="text-sm text-green-700 bg-green-50 border border-green-200 rounded px-3 py-2 mb-4">
      <%= @flash["info"] %>
    </p>
  <% end %>

  <%# Formulario nuevo mensaje — ahora con campo destinatario %>
  <form phx-submit="enviar_mensaje"
    class="bg-white border border-gray-200 rounded p-5 max-w-md space-y-4 text-sm mb-6">
    <div>
      <label class="block text-gray-600 mb-1">Destinatario (usuario)</label>
      <input type="text" name="destinatario"
        class="w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
        placeholder="Ej: vendedor, maria, etc." />
    </div>
    <div>
      <label class="block text-gray-600 mb-1">ID de propiedad (opcional)</label>
      <input type="text" name="propiedad_id" value={@mensaje_propiedad_id}
        class="w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
        placeholder="Ej: prop12345 — si escribes esto, va al propietario" />
    </div>
    <div>
      <label class="block text-gray-600 mb-1">Mensaje</label>
      <textarea name="mensaje" rows="2" required
        class="w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
        placeholder="Escribe tu mensaje..."><%= @mensaje_texto %></textarea>
    </div>
    <input type="hidden" name="reply_to" value="" />
    <button type="submit"
      class="bg-blue-700 hover:bg-blue-800 text-white text-sm px-4 py-2 rounded transition">
      Enviar mensaje
    </button>
  </form>

  <%# Historial %>
  <% yo = @current_user["username"] %>
  <% mensajes = Inmobiliaria.MessageManager.get_messages_for_user(yo) %>

  <%= if mensajes == [] do %>
    <p class="text-sm text-gray-500">No tienes mensajes aún.</p>
  <% else %>
    <div class="space-y-3 max-w-lg">
      <%= for m <- mensajes do %>
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
            <p class="text-xs text-gray-400 mb-2">Propiedad: <%= m.property_id %></p>
          <% end %>

          <%# Responder — solo si yo soy el destinatario %>
          <%= if m.recipient == yo do %>
            <form phx-submit="enviar_mensaje" class="flex gap-2 mt-2">
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
