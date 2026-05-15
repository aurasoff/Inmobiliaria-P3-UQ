# Sistema Inmobiliario — Phoenix Web

Universidad del Quindío — Programación III

## Requisitos

- Elixir 1.14 o superior (ya lo tienes instalado)
- Conexión a internet (para descargar dependencias)

## Instalación y ejecución

### 1. Entrar a la carpeta del proyecto

```cmd
cd inmobiliaria_phoenix
```

### 2. Descargar dependencias

```cmd
mix deps.get
```

### 3. Iniciar el servidor web

```cmd
mix phx.server
```

O con consola interactiva:

```cmd
iex -S mix phx.server     (Linux/Mac)
iex.bat -S mix phx.server (Windows CMD)
```

### 4. Abrir en el navegador

```
http://localhost:4000
```

---

## Estructura del proyecto

```
inmobiliaria_phoenix/
├── lib/
│   ├── core/                        ← Lógica de dominio reutilizada del proyecto TCP
│   │   ├── file_utils.ex
│   │   ├── location.ex
│   │   ├── user_manager.ex
│   │   ├── property_manager.ex
│   │   ├── message_manager.ex
│   │   ├── results_logger.ex
│   │   ├── property.ex              ← GenServer por propiedad
│   │   ├── property_registry.ex
│   │   ├── property_supervisor.ex
│   │   └── session_manager.ex
│   ├── inmobiliaria_phoenix/
│   │   └── application.ex           ← Árbol OTP
│   └── inmobiliaria_phoenix_web/
│       ├── live/
│       │   ├── auth_live.ex         ← Login y registro
│       │   ├── ranking_live.ex      ← Rankings
│       │   └── properties_live/
│       │       ├── index.ex         ← Lista con filtros
│       │       ├── show.ex          ← Detalle, compra, mensajes
│       │       └── new.ex           ← Publicar propiedad
│       ├── components/
│       │   └── layouts/             ← Layout con navbar
│       └── router.ex
├── data/                            ← Archivos .dat y .log (persistencia)
└── config/
```

## Páginas disponibles

| URL | Descripción |
|-----|-------------|
| `/` | Lista de propiedades con filtros |
| `/register` | Crear cuenta |
| `/login` | Iniciar sesión |
| `/properties/new` | Publicar propiedad (vendedor/arrendador) |
| `/properties/:id` | Ver, comprar/arrendar, enviar mensajes |
| `/ranking` | Rankings generales y por rol |
| `/logout` | Cerrar sesión |
