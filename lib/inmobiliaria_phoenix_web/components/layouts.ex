defmodule InmobiliariaPhoenixWeb.Layouts do
  use InmobiliariaPhoenixWeb, :html

  import Phoenix.VerifiedRoutes,
    only: [sigil_p: 2],
    warn: false

  embed_templates "layouts/*"
end
