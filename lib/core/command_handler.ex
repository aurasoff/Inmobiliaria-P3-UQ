defmodule Inmobiliaria.CommandHandler do
  @moduledoc """
  Lógica de cada comando del sistema.
  Recibe la tupla de comando + session_state, ejecuta la acción y retorna {respuesta, nuevo_estado}.
  """

  alias Inmobiliaria.{
    SessionManager,
    PropertySupervisor,
    PropertyManager,
    MessageManager,
    UserManager,
    ResultsLogger,
    Location
  }

  @doc """
  Procesa un comando y retorna {response_string, new_session_state}.
  session_state: %{username: nil | String.t(), rol: nil | String.t()}
  """
  def handle(command, session) do
    do_handle(command, session)
  end

  # ─── connect ────────────────────────────────────────────────────────────────

  defp do_handle({:connect, username, password}, session) do
    if session.username != nil do
      {"❌ Error: ya estás conectado como #{session.username}. Usa 'disconnect' primero.", session}
    else
      case SessionManager.connect(username, password, self()) do
        {:ok, user} ->
          new_session = %{username: user.username, rol: user.rol}
          msg = "✅ Bienvenido, #{user.username}! Conectado como #{user.rol}. Puntaje actual: #{user.puntaje}"
          {msg, new_session}

        {:error, :not_found} ->
          {"❌ Error: usuario '#{username}' no encontrado. Usa 'register' para crear una cuenta.", session}

        {:error, :invalid_credentials} ->
          {"❌ Error: contraseña incorrecta.", session}
      end
    end
  end

  # ─── register ───────────────────────────────────────────────────────────────

  defp do_handle({:register, username, password, rol}, session) do
    roles_validos = ["cliente", "vendedor", "arrendador"]

    if rol not in roles_validos do
      {"❌ Error: rol inválido. Usa: #{Enum.join(roles_validos, ", ")}", session}
    else
      case UserManager.register_user(username, rol, password) do
        :ok ->
          {"✅ Usuario '#{username}' registrado como #{rol}. Ahora usa 'connect #{username} #{password}'.", session}

        {:error, :already_exists} ->
          {"❌ Error: el usuario '#{username}' ya existe.", session}
      end
    end
  end

  # ─── disconnect ─────────────────────────────────────────────────────────────

  defp do_handle(:disconnect, session) do
    case require_auth(session) do
      {:error, msg} ->
        {msg, session}

      :ok ->
        SessionManager.disconnect(session.username)
        {"👋 Hasta luego, #{session.username}!", %{username: nil, rol: nil}}
    end
  end

  # ─── publish_property ───────────────────────────────────────────────────────

  defp do_handle({:publish_property, args}, session) do
    with :ok <- require_role(session, ["vendedor", "arrendador"]),
         :ok <- validate_publish_args(args) do

      ubicacion = to_string(Map.get(args, :ubicacion, ""))
      modalidad = to_string(Map.get(args, :modalidad, ""))

      cond do
        not Location.valid_location?(ubicacion) ->
          locs = Enum.join(Location.list_locations(), ", ")
          {"❌ Error: ubicación '#{ubicacion}' no válida. Ubicaciones disponibles: #{locs}", session}

        modalidad not in ["venta", "arriendo"] ->
          {"❌ Error: modalidad debe ser 'venta' o 'arriendo'.", session}

        true ->
          property = %PropertyManager{
            id: PropertyManager.generate_id(),
            tipo: to_string(Map.get(args, :tipo)),
            modalidad: modalidad,
            ubicacion: ubicacion,
            precio: parse_int(Map.get(args, :precio)),
            habitaciones: parse_int(Map.get(args, :habitaciones)),
            area: parse_float(Map.get(args, :area)),
            estado: "disponible",
            propietario: session.username
          }

          case PropertyManager.save_property(property) do
            :ok ->
              PropertySupervisor.start_property(property)
              {"✅ Propiedad publicada con ID: #{property.id}\n" <>
                "   Tipo: #{property.tipo} | Modalidad: #{property.modalidad} | Ubicación: #{property.ubicacion}\n" <>
                "   Precio: $#{property.precio} | Hab: #{property.habitaciones} | Área: #{property.area}m²",
               session}

            {:error, :already_exists} ->
              {"❌ Error: ya existe una propiedad con ese ID.", session}
          end
      end
    else
      {:error, msg} -> {msg, session}
    end
  end

  # ─── list_properties ────────────────────────────────────────────────────────

  defp do_handle(:list_properties, session) do
    do_handle({:list_properties, %{}}, session)
  end

  defp do_handle({:list_properties, filters}, session) do
    properties = PropertyManager.list_available(filters)

    if properties == [] do
      {"📭 No hay propiedades disponibles con esos criterios.", session}
    else
      header = "╔══ PROPIEDADES DISPONIBLES (#{length(properties)}) ══════════════════════════╗"
      rows = Enum.map(properties, &format_property/1)
      footer = "╚══════════════════════════════════════════════════════════════╝"
      {Enum.join([header | rows] ++ [footer], "\n"), session}
    end
  end

  # ─── buy_property ───────────────────────────────────────────────────────────

  defp do_handle({:buy_property, property_id}, session) do
    with :ok <- require_role(session, ["cliente"]) do
      case Registry.lookup(Inmobiliaria.PropertyRegistry, property_id) do
        [] ->
          {"❌ Error: propiedad '#{property_id}' no encontrada o no disponible.", session}

        [{pid, _}] ->
          case GenServer.call(pid, {:buy, session.username}) do
            {:ok, _property} ->
              {"🎉 ¡Compra exitosa! Adquiriste la propiedad #{property_id}.\n" <>
                "   +10 puntos a tu cuenta. Gracias por usar el sistema.",
               session}

            {:error, :not_available} ->
              {"❌ La propiedad #{property_id} ya no está disponible (fue comprada o arrendada).", session}
          end
      end
    else
      {:error, msg} -> {msg, session}
    end
  end

  # ─── rent_property ──────────────────────────────────────────────────────────

  defp do_handle({:rent_property, property_id}, session) do
    with :ok <- require_role(session, ["cliente"]) do
      case Registry.lookup(Inmobiliaria.PropertyRegistry, property_id) do
        [] ->
          {"❌ Error: propiedad '#{property_id}' no encontrada o no disponible.", session}

        [{pid, _}] ->
          case GenServer.call(pid, {:rent, session.username}) do
            {:ok, _property} ->
              {"🎉 ¡Arriendo exitoso! Arrendaste la propiedad #{property_id}.\n" <>
                "   +10 puntos a tu cuenta.",
               session}

            {:error, :not_available} ->
              {"❌ La propiedad #{property_id} ya no está disponible.", session}
          end
      end
    else
      {:error, msg} -> {msg, session}
    end
  end

  # ─── send_message ───────────────────────────────────────────────────────────

  defp do_handle({:send_message, property_id, message}, session) do
    with :ok <- require_auth(session) do
      case PropertyManager.find_property(property_id) do
        {:error, :not_found} ->
          {"❌ Error: propiedad '#{property_id}' no encontrada.", session}

        {:ok, property} ->
          MessageManager.send_message(property_id, session.username, property.propietario, message)
          {"✉️  Mensaje enviado al propietario de #{property_id} (#{property.propietario}).", session}
      end
    else
      {:error, msg} -> {msg, session}
    end
  end

  # ─── get_messages ───────────────────────────────────────────────────────────

  defp do_handle({:get_messages, property_id}, session) do
    with :ok <- require_auth(session) do
      case PropertyManager.find_property(property_id) do
        {:error, :not_found} ->
          {"❌ Error: propiedad '#{property_id}' no encontrada.", session}

        {:ok, property} ->
          if property.propietario != session.username do
            {"❌ Error: solo el propietario puede ver los mensajes de esta propiedad.", session}
          else
            messages = MessageManager.get_messages_for_property(property_id)

            if messages == [] do
              {"📭 No hay mensajes para la propiedad #{property_id}.", session}
            else
              rows = Enum.map(messages, fn {ts, sender, msg} ->
                "  [#{ts}] #{sender}: #{msg}"
              end)
              {"📬 Mensajes para #{property_id}:\n" <> Enum.join(rows, "\n"), session}
            end
          end
      end
    else
      {:error, msg} -> {msg, session}
    end
  end

  # ─── my_score ───────────────────────────────────────────────────────────────

  defp do_handle(:my_score, session) do
    with :ok <- require_auth(session) do
      case UserManager.find_user(session.username) do
        {:ok, user} ->
          {"⭐ Puntaje de #{user.username} (#{user.rol}): #{user.puntaje} puntos", session}

        {:error, _} ->
          {"❌ Error al obtener puntaje.", session}
      end
    else
      {:error, msg} -> {msg, session}
    end
  end

  # ─── ranking ────────────────────────────────────────────────────────────────

  defp do_handle(:ranking, session) do
    ranking = UserManager.get_ranking()

    if ranking == [] do
      {"📊 No hay usuarios registrados aún.", session}
    else
      header = "╔══ RANKING GLOBAL ══════════════════════════════╗"
      rows =
        ranking
        |> Enum.with_index(1)
        |> Enum.map(fn {{username, rol, puntaje}, i} ->
          medal = case i do
            1 -> "🥇"
            2 -> "🥈"
            3 -> "🥉"
            _ -> "  #{i}."
          end
          "  #{medal} #{username} (#{rol}) — #{puntaje} pts"
        end)
      footer = "╚════════════════════════════════════════════════╝"
      {Enum.join([header | rows] ++ [footer], "\n"), session}
    end
  end

  # ─── rankings específicos ───────────────────────────────────────────────────

  defp do_handle(:ranking_compradores, session) do
    ranking = ResultsLogger.get_ranking_compradores()
    {format_simple_ranking("COMPRADORES", ranking), session}
  end

  defp do_handle(:ranking_vendedores, session) do
    ranking = ResultsLogger.get_ranking_vendedores()
    {format_simple_ranking("VENDEDORES", ranking), session}
  end

  defp do_handle(:ranking_arrendadores, session) do
    ranking = ResultsLogger.get_ranking_arrendadores()
    {format_simple_ranking("ARRENDADORES", ranking), session}
  end

  # ─── sessions ───────────────────────────────────────────────────────────────

  defp do_handle(:sessions, session) do
    sessions = SessionManager.list_sessions()

    if map_size(sessions) == 0 do
      {"👥 No hay usuarios conectados.", session}
    else
      rows = Enum.map(sessions, fn {username, info} ->
        "  • #{username} (#{info.rol}) — conectado desde #{info.connected_at}"
      end)
      {"👥 Usuarios conectados (#{map_size(sessions)}):\n" <> Enum.join(rows, "\n"), session}
    end
  end

  # ─── help ───────────────────────────────────────────────────────────────────

  defp do_handle(:help, session) do
    sep  = "+" <> String.duplicate("=", 66) <> "+"
    sep2 = "+" <> String.duplicate("-", 66) <> "+"

    lines = [
      sep,
      "|      SISTEMA INMOBILIARIO -- COMANDOS DISPONIBLES              |",
      sep2,
      "| AUTENTICACION                                                    |",
      "|  register <usuario> <clave> <rol>   Crear cuenta                |",
      "|    roles: cliente | vendedor | arrendador                        |",
      "|  connect <usuario> <clave>          Iniciar sesion              |",
      "|  disconnect                         Cerrar sesion               |",
      sep2,
      "| PROPIEDADES (requiere rol vendedor/arrendador)                   |",
      "|  publish_property tipo=X modalidad=X ubicacion=X                 |",
      "|    precio=X habitaciones=X area=X                                |",
      sep2,
      "| CONSULTAS (todos)                                                |",
      "|  list_properties                    Ver disponibles              |",
      "|  list_properties tipo=X             Filtrar por tipo             |",
      "|  list_properties modalidad=X        Filtrar por modalidad        |",
      "|  list_properties ubicacion=X        Filtrar por ubicacion        |",
      "|  list_properties precio_min=X       Filtrar precio minimo        |",
      "|  list_properties precio_max=X       Filtrar precio maximo        |",
      sep2,
      "| OPERACIONES (requiere rol cliente)                               |",
      "|  buy_property <id>                  Comprar propiedad            |",
      "|  rent_property <id>                 Arrendar propiedad           |",
      sep2,
      "| MENSAJES (requiere autenticacion)                                |",
      "|  send_message <id> <mensaje>        Enviar mensaje               |",
      "|  get_messages <id>                  Ver mensajes (propietario)   |",
      sep2,
      "| ESTADISTICAS                                                     |",
      "|  my_score                           Ver mi puntaje               |",
      "|  ranking                            Ranking general              |",
      "|  ranking_compradores                Top compradores              |",
      "|  ranking_vendedores                 Top vendedores               |",
      "|  ranking_arrendadores               Top arrendadores             |",
      "|  sessions                           Usuarios conectados          |",
      sep
    ]

    {Enum.join(lines, "\n"), session}
  end

  # ─── unknown ────────────────────────────────────────────────────────────────

  defp do_handle({:unknown, raw}, session) do
    {"❓ Comando no reconocido: '#{raw}'. Escribe 'help' para ver los comandos disponibles.", session}
  end

  defp do_handle(_, session) do
    {"❓ Comando no reconocido. Escribe 'help' para ver los comandos disponibles.", session}
  end

  # ─── Helpers privados ────────────────────────────────────────────────────────

  defp require_auth(session) do
    if session.username == nil do
      {:error, "❌ Error: debes conectarte primero. Usa 'connect <usuario> <clave>'."}
    else
      :ok
    end
  end

  defp require_role(session, roles) do
    cond do
      session.username == nil ->
        {:error, "❌ Error: debes conectarte primero. Usa 'connect <usuario> <clave>'."}

      session.rol not in roles ->
        {:error, "❌ Error: esta acción requiere rol #{Enum.join(roles, " o ")}. Tu rol es '#{session.rol}'."}

      true ->
        :ok
    end
  end

  defp validate_publish_args(args) do
    required = [:tipo, :modalidad, :ubicacion, :precio, :habitaciones, :area]
    missing = Enum.filter(required, &(not Map.has_key?(args, &1)))

    if missing == [] do
      :ok
    else
      {:error, "❌ Error: faltan campos requeridos: #{Enum.join(missing, ", ")}"}
    end
  end

  defp format_property(p) do
    "  [#{p.id}] #{String.upcase(p.tipo)} en #{p.modalidad}\n" <>
      "   📍 #{p.ubicacion} | 💰 $#{p.precio} | 🛏 #{p.habitaciones} hab | 📐 #{p.area}m²\n" <>
      "   👤 Propietario: #{p.propietario}"
  end

  defp format_simple_ranking(title, ranking) do
    if ranking == [] do
      "📊 No hay datos para el ranking de #{title}."
    else
      header = "╔══ RANKING #{title} ══════════════════════╗"
      rows =
        ranking
        |> Enum.with_index(1)
        |> Enum.map(fn {{username, count}, i} ->
          "  #{i}. #{username} — #{count} operaciones"
        end)
      footer = "╚═════════════════════════════════════════════╝"
      Enum.join([header | rows] ++ [footer], "\n")
    end
  end

  defp parse_int(v) when is_integer(v), do: v
  defp parse_int(v) when is_binary(v), do: String.to_integer(v)
  defp parse_int(v) when is_atom(v), do: String.to_integer(Atom.to_string(v))

  defp parse_float(v) when is_float(v), do: v
  defp parse_float(v) when is_integer(v), do: v * 1.0
  defp parse_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> String.to_integer(v) * 1.0
    end
  end
  defp parse_float(v) when is_atom(v), do: parse_float(Atom.to_string(v))
end
