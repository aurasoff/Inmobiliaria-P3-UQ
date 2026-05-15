defmodule InmobiliariaPhoenixWeb.CoreComponents do
  use Phoenix.Component

  attr :flash, :map, required: true
  def flash_group(assigns) do
    ~H"""
    <div class="fixed top-4 right-4 z-50 space-y-2">
      <%= for {kind, msg} <- @flash do %>
        <div class={[
          "px-4 py-3 rounded-lg shadow-lg text-white text-sm font-medium max-w-sm",
          kind == "info" && "bg-blue-600",
          kind == "error" && "bg-red-600",
          kind == "success" && "bg-green-600"
        ]}>
          <%= msg %>
        </div>
      <% end %>
    </div>
    """
  end
end
