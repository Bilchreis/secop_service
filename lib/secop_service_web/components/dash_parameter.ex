defmodule SecopServiceWeb.Components.DashParameter do
  use Phoenix.LiveComponent

  alias SecopService.Util
  alias SecopServiceWeb.Components.ParameterValueDisplay
  import SecopServiceWeb.SECoPComponents
  import SecopServiceWeb.Components.ParameterFormFieldComponents
  import SecopServiceWeb.CoreComponents
  alias Phoenix.LiveView.JS

  def handle_event("show_graph", _params, socket) do
    send(self(), {:show_parameter_graph, socket.assigns.parameter})
    {:noreply, socket}
  end



  def render(assigns) do
    ~H"""
    <div>
      <div class="card mb-4 bg-neutral p-4 shadow-md">
        <div class="flex justify-between">
          <div class="flex ">
            <div>
              <.datainfo_tooltip datainfo={@parameter.datainfo} position="tooltip-right" />
            </div>

            <div class="text-lg font-bold text-neutral-content">
              {Util.display_name(@parameter.name)}:
            </div>
          </div>

          <div class="flex text-sm text-base-content pt-1 gap-2">
            <div class=" px-2 py-0.5 rounded-full bg-base-100 font-mono">
              {@parameter.datainfo["type"]}
            </div>
            <%= if @parameter.readonly do %>
              <div class=" px-2 py-0.5 rounded-full bg-base-100 font-mono">
                r
              </div>
            <% else %>
              <div class="px-2 py-0.5 rounded-full bg-base-100 font-mono">
                r/w
              </div>
            <% end %>

            <button
              class="btn btn-warning btn-sm"
              phx-click={JS.push("show_graph", target: @myself)}
            >
              <div class="flex items-center">
                <.icon name="hero-chart-bar-solid" class="h-5 w-5 flex-none mr-1" /> Graph
              </div>
            </button>
          </div>
        </div>

        <ul class="mt-2 text-sm text-neutral-content/80">
          <.property
            prop_key="Description"
            class=""
            key_class="text-neutral-content/80 text-sm font-bold"
          >
            {@parameter.description}
          </.property>

          <%= if @parameter.meaning do %>
            <.property prop_key="Meaning" key_class="text-neutral-content/80 font-semibold">
              {inspect(@parameter.meaning)}
            </.property>
          <% end %>

          <%= if @parameter.checkable do %>
            <.property prop_key="Checkable" key_class="text-neutral-content/80 font-semibold">
              {@parameter.checkable}
            </.property>
          <% end %>

          <%= for {property_name, property_value} <- @parameter.custom_properties do %>
            <.property
              prop_key={String.replace_prefix(property_name, "_", "")}
              key_class="text-neutral-content/80 font-semibold"
            >
              > {inspect(property_value)}
            </.property>
          <% end %>
        </ul>

        <.live_component
          module={ParameterValueDisplay}
          id={"parameter_value:" <> @node_id_str <> ":" <> @module_name <> ":" <> @parameter.name}
          class=""
          host={@host}
          port={@port}
          location="parameter_value"
          module_name={@module_name}
          parameter={@parameter}
          id_str={"parameter_value:" <> @node_id_str <> ":" <> @module_name <> ":" <> @parameter.name}
        />
      </div>

    </div>
    """
  end
end
