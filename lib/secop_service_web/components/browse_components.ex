defmodule SecopServiceWeb.BrowseComponents do
  use Phoenix.Component
  alias SecopService.Sec_Nodes.SEC_Node
  alias SecopService.Sec_Nodes.Module
  alias SecopService.Util
  alias Jason
  attr :node, :map, required: true

  def sec_node_view(assigns) do
    grouped_modules = Enum.group_by(assigns.node.modules, &(&1.group || nil))


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
                    class="border-4 border-zinc-300 dark:border-zinc-600 bg-zinc-200 dark:bg-zinc-800 p-2 rounded-lg"
                    key_class="text-lg"
                  >
                    <div class="rounded-lg text-base">{SEC_Node.display_description(@node)}</div>
                  </.property>
                </ul>
              </div>
              <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-zinc-200 dark:bg-zinc-800 p-2 rounded-lg mt-2">
                <p class="text-lg font-bold">Node Properties:</p>

                <ul class="text-sm font-medium border-purple-500 rounded-lg">
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
            <ul class="text-lg font-medium text-right">
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
      <div class="mt-6 bg-gray-100 dark:bg-gray-700 rounded-lg p-4">
        <h2 class="text-2xl font-bold mb-4">Modules:</h2>

        <%= for {group_name, modules} <- Enum.sort(@grouped_modules) do %>
          <%= if group_name == nil do %>
            <%= for module <- modules do %>
              <.module module={module} />
            <% end %>
          <% else %>
            <div class="mb-6 border-l-4 border-purple-500 pl-4">
              <h3 class="text-xl font-semibold mb-2 text-purple-700 dark:text-purple-400">
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
    grouped_parameters = Enum.group_by(assigns.module.parameters, &(&1.group || nil))
    grouped_commands = Enum.group_by(assigns.module.commands, &(&1.group || nil))

    assigns = assigns
      |> assign(:grouped_parameters, grouped_parameters)
      |> assign(:grouped_commands, grouped_commands)

    ~H"""
    <div class="bg-gray-300 dark:bg-gray-700 rounded-lg p-4 mb-6 shadow-md">
      <!-- Module Name -->
      <div class="mb-4">
        <span class="text-2xl font-bold text-gray-800 dark:text-white">{Module.display_name(@module)}</span>
      </div>

      <!-- Module Properties -->
      <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-gray-200 dark:bg-gray-800 rounded-lg p-4">
        <h3 class="text-lg font-bold text-purple-700 dark:text-purple-400 mb-2">Module Properties:</h3>
        <ul class="text-sm text-gray-700 dark:text-gray-300 space-y-2">
          <.property prop_key="Description" key_class="text-gray-700 dark:text-gray-300 text-sm font-bold">
            {@module.description}
          </.property>
          <.property prop_key="Interface Classes" key_class="text-gray-600 dark:text-gray-400 font-semibold">
            {@module.interface_classes |> Enum.join(", ")}
          </.property>

          <%= if @module.implementor do %>
            <.property prop_key="Implementor" key_class="text-gray-600 dark:text-gray-400 font-semibold">
              {@module.implementor}
            </.property>
          <% end %>

          <%= if @module.group do %>
            <.property prop_key="Group" key_class="text-gray-600 dark:text-gray-400 font-semibold">
              {@module.group}
            </.property>
          <% end %>

          <%= if @module.meaning do %>
            <.property prop_key="Meaning" key_class="text-gray-600 dark:text-gray-400 font-semibold">
              {inspect(@module.meaning)}
            </.property>
          <% end %>

          <%= for {property_name, property_value} <- @module.custom_properties do %>
            <.property prop_key={String.replace_prefix(property_name, "_", "")} key_class="text-gray-600 dark:text-gray-400 font-semibold">
              {inspect(property_value)}
            </.property>
          <% end %>
        </ul>
      </div>

      <!-- Parameters -->
      <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-gray-200 dark:bg-gray-800 rounded-lg p-4 mt-4">
        <h3 class="text-lg font-bold text-purple-700 dark:text-purple-400 mb-2">Parameters:</h3>
        <%= for {group_name, parameters} <- Enum.sort(@grouped_parameters) do %>
          <%= if group_name == nil do %>
            <div class="mt-4 border-l-4 border-transparent pl-4">
              <%= for parameter <- parameters do %>
                <.parameter parameter={parameter} />
              <% end %>
            </div>
          <% else %>
            <div class="mt-4 border-l-4 border-purple-500 pl-4">
              <h4 class="text-xl font-semibold mb-2 text-purple-700 dark:text-purple-400">
                {Util.display_name(group_name)}
              </h4>
              <%= for parameter <- parameters do %>
                <.parameter parameter={parameter} />
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>

      <!-- Commands -->
      <%= if @module.commands != [] do %>
        <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-gray-200 dark:bg-gray-800 rounded-lg p-4 mt-4">
          <h3 class="text-lg font-bold text-purple-700 dark:text-purple-400 mb-2">Commands:</h3>
          <%= for {group_name, commands} <- Enum.sort(@grouped_commands) do %>
            <%= if group_name == nil do %>
              <div class="mt-4 border-l-4 border-transparent pl-4">
                <%= for command <- commands do %>
                  <.command command={command} />
                <% end %>
              </div>
            <% else %>
              <div class="mt-4 border-l-4 border-purple-500 pl-4">
                <h4 class="text-xl font-semibold mb-2 text-purple-700 dark:text-purple-400">
                  {Util.display_name(group_name)}
                </h4>
                <%= for command <- commands do %>
                  <.command command={command} />
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end


  attr :parameter, :map, required: true

  def parameter(assigns) do
    datainfo_pretty = Jason.encode!(assigns.parameter.datainfo, pretty: true)

    assigns = assigns
      |> assign(:datainfo_pretty, datainfo_pretty)

    ~H"""
    <div class="mb-4 bg-gray-300 dark:bg-gray-700 rounded-lg p-4 shadow-md">
      <div class="grid grid-cols-2 gap-4">
        <!-- Parameter Name -->
        <div>
          <span class="text-xl font-bold text-gray-800 dark:text-white">{Util.display_name(@parameter.name)}:</span>
          <ul class="mt-2 text-sm text-gray-700 dark:text-gray-300">
            <!-- Description -->
            <.property prop_key="Description" class = "rounded-lg bg-gray-200 dark:bg-gray-600 mb-2 p-2" key_class="text-gray-700 dark:text-gray-300 text-sm font-bold">
              {@parameter.description}
            </.property>

            <!-- Readonly -->
            <.property prop_key="Readonly" key_class="text-gray-600 dark:text-gray-400 font-semibold">
              <%= if @parameter.readonly do %>
                <span class="text-amber-600 dark:text-amber-400">🔒 Read-only</span>
              <% else %>
                <span class="text-green-600 dark:text-green-400">✏️ Writable</span>
              <% end %>
            </.property>

            <!-- Optional Properties -->
            <%= if @parameter.group do %>
              <.property prop_key="Group" key_class="text-gray-600 dark:text-gray-400 font-semibold">
                {@parameter.group}
              </.property>
            <% end %>

            <%= if @parameter.visibility do %>
              <.property prop_key="Visibility" key_class="text-gray-600 dark:text-gray-400 font-semibold">
                {@parameter.visibility}
              </.property>
            <% end %>

            <%= if @parameter.meaning do %>
              <.property prop_key="Meaning" key_class="text-gray-600 dark:text-gray-400 font-semibold">
                {inspect(@parameter.meaning)}
              </.property>
            <% end %>

            <%= if @parameter.checkable do %>
              <.property prop_key="Checkable" key_class="text-gray-600 dark:text-gray-400 font-semibold">
                {@parameter.checkable}
              </.property>
            <% end %>

            <!-- Custom Properties -->
            <%= for {property_name, property_value} <- @parameter.custom_properties do %>
              <.property prop_key={String.replace_prefix(property_name, "_", "")} key_class="text-gray-600 dark:text-gray-400 font-semibold">
                {inspect(property_value)}
              </.property>
            <% end %>
          </ul>
        </div>

        <!-- Datainfo -->
        <div>
          <ul class="text-sm font-semibold text-gray-700 dark:text-gray-300">
            <.property prop_key="Datainfo" key_class="text-gray-600 dark:text-gray-400 font-semibold">
              <pre class="whitespace-pre-wrap break-words max-h-[60vh] overflow-y-auto bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200 font-mono text-xs p-2 rounded-lg border border-zinc-300 dark:border-zinc-600">
                {@datainfo_pretty}
              </pre>
            </.property>
          </ul>
        </div>
      </div>
    </div>
    """
  end


  attr :command, :map, required: true

  def command(assigns) do
    ~H"""
    <div class="text-gray-800 dark:text-gray-200">
      {@command.name}
    </div>
    """
  end
end
