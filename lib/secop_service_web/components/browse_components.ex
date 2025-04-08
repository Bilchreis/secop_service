defmodule SecopServiceWeb.BrowseComponents do
  use Phoenix.Component
  alias SecopService.Sec_Nodes.SEC_Node
  alias SecopService.Sec_Nodes.Module

  attr :node, :map, required: true

  def sec_node_view(assigns) do
    grouped_modules = Enum.group_by(assigns.node.modules, &(&1.group || "Ungrouped"))

    assigns = assign(assigns, :grouped_modules, grouped_modules)

    ~H"""
    <div class="bg-gray-200 dark:bg-gray-900 dark:text-gray-300 p-4 rounded-lg shadow-md">
      <div class="bg-gray-100 dark:bg-gray-700 rounded-lg p-4">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <span class="bg-gradient-to-r from-purple-500 to-purple-600 bg-clip-text text-4xl font-bold text-transparent">
              {SEC_Node.display_equipment_id(@node)}
            </span>
            <div class="grid grid-cols-2 gap-4 mt-2">
              <div>
                <ul class="mt-2 text-sm font-medium">
                  <.property
                    prop_key="Description"
                    class="border-4 border-zinc-500  bg-zinc-800 p-2 rounded-lg"
                    key_class="text-lg"
                  >
                    <div class="rounded-lg    text-base">{SEC_Node.display_description(@node)}</div>
                  </.property>
                </ul>
              </div>
              <div class="border-4 border-zinc-500 bg-zinc-800 p-2 rounded-lg mt-2">
                <p class="text-lg font-bold">Node Properties:</p>

                <ul class=" text-sm font-medium  border-purple-500 rounded-lg">
                  <.property prop_key="Equipment ID">
                    {@node.equipment_id}
                  </.property>

                  <%= if @node.implementor do %>
                    <.property prop_key="Implementor">
                      {@node.implementor}
                    </.property>
                  <% end %>

                  <%= if @node.timeout do %>
                    <.property prop_key="Timeout">
                      {@node.timeout}
                    </.property>
                  <% end %>

                  <%= if @node.firmware do %>
                    <.property prop_key="Firmware">
                      {@node.firmware}
                    </.property>
                  <% end %>

                  <%= for {property_name, property_value} <- @node.custom_properties do %>
                    <.property prop_key={String.replace_prefix(property_name, "_", "")}>
                      {inspect(property_value)}
                    </.property>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>
          <div>
            <ul class="text-sm font-medium text-right ">
              <.property prop_key="UUID" value_class="font-mono">
                {@node.uuid}
              </.property>

              <.property prop_key="URI" value_class="font-mono">
                {@node.host <> ":" <> to_string(@node.port)}
              </.property>

              <.property prop_key="Created at">
                {@node.inserted_at
                |> DateTime.from_naive!("Etc/UTC")
                |> DateTime.shift_zone!("Europe/Berlin")
                |> Calendar.strftime("%d.%m.%Y %H:%M")}
              </.property>
            </ul>
          </div>
        </div>
      </div>
      
    <!--Modules -->
      <div class="mt-6 bg-gray-100 dark:bg-gray-700   rounded-lg p-4">
        <h2 class="text-3xl font-bold mb-4">Modules</h2>

        <%= for {group_name, modules} <- Enum.sort(@grouped_modules) do %>
          <%= if group_name == "Ungrouped" do %>
            <%= for module <- modules do %>
              <.module module={module} />
            <% end %>
          <% else %>
            <div class="mb-6 border-l-4 border-purple-500 pl-4">
              <h3 class="text-xl font-semibold mb-2 text-purple-500 dark:text-purple-500">
                {group_name}
              </h3>

              <%= for module <- modules do %>
                <.module module={module} />
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  attr :prop_key, :string, required: true
  attr :class, :any
  attr :key_class, :any
  attr :value_class, :any
  slot :inner_block, required: true

  def property(assigns) do
    ~H"""
    <li class={["", assigns[:class]]}>
      <span class={["font-bold", assigns[:key_class]]}>{@prop_key}:</span>
      <span class={["", assigns[:value_class]]}>{render_slot(@inner_block)}</span>
    </li>
    """
  end

  attr :module, :map, required: true

  def module(assigns) do
    grouped_parameters = Enum.group_by(assigns.module.parameters, &(&1.group || "Ungrouped"))

    assigns = assign(assigns, :grouped_parameters, grouped_parameters)

    ~H"""
    <div class="bg-gray-600 rounded-lg p-4 mb-4">
      <span class="text-2xl font-bold">{Module.display_name(@module)}</span>
      <div class="border-4 border-zinc-500 bg-zinc-800 rounded-lg p-2">
        <span class="text-lg font-bold">Module Properties:</span>
        <ul class=" text-sm font-medium  rounded-lg ">
          <.property prop_key="Description">
            {@module.description}
          </.property>
          <.property prop_key="Interface Classes">
            {@module.interface_classes |> Enum.join(", ")}
          </.property>

          <%= if @module.implementor do %>
            <.property prop_key="Implementor">
              {@module.implementor}
            </.property>
          <% end %>

          <%= if @module.group do %>
            <.property prop_key="Group">
              {@module.group}
            </.property>
          <% end %>

          <%= if @module.meaning do %>
            <.property prop_key="Meaning">
              {inspect(@module.meaning)}
            </.property>
          <% end %>

          <%= for {property_name, property_value} <- @module.custom_properties do %>
            <.property prop_key={String.replace_prefix(property_name, "_", "")}>
              {inspect(property_value)}
            </.property>
          <% end %>
        </ul>
      </div>
      
    <!--Parameters -->
      <div class="border-4 border-zinc-500 bg-zinc-800 rounded-lg p-2 mt-4">
        <span class="text-lg font-bold">Parameters:</span>

        <%= for {group_name, parameters} <- Enum.sort(@grouped_parameters) do %>
          <%= if group_name == "Ungrouped" do %>
            <%= for parameter <- parameters do %>
              <.parameter parameter={parameter} />
            <% end %>
          <% else %>
            <div class="mb-6 border-l-4 border-purple-500 pl-4">
              <h3 class="text-xl font-semibold mb-2 text-purple-500 dark:text-purple-500">
                {group_name}
              </h3>

              <%= for parameter <- parameters do %>
                <.parameter parameter={parameter} />
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  attr :parameter, :map, required: true

  def parameter(assigns) do
    ~H"""
    <div>
      {@parameter.name}
    </div>
    """
  end
end
