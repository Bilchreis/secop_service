defmodule SecopServiceWeb.DashboardComponents do
  use Phoenix.Component

  alias Ecto.Migration.Command
  alias Credo.Code.Charlists
  alias Credo.Check.Readability.ModuleAttributeNames
  alias SecopService.Sec_Nodes.SEC_Node
  alias SecopService.Sec_Nodes.Module

  alias SecopService.Util
  alias Jason
  alias SecopServiceWeb.Components.ModuleIndicator
  alias SecopServiceWeb.Components.ParameterValueDisplay

  import SECoPComponents
  import SecopServiceWeb.BrowseComponents
  import SecopServiceWeb.CoreComponents

  attr :node, :map, required: true

  def dash_sec_node(assigns) do
    grouped_modules = Enum.group_by(assigns.node.modules, &(&1.group || nil))

    assigns =
      assign(assigns, :grouped_modules, grouped_modules)
      |> assign(:n_modules, length(assigns.node.modules))

    ~H"""
    <div class="flex-1 mt-4 ml-3 p-3 bg-gray-50 text-medium text-gray-500 dark:text-gray-400 dark:bg-gray-900 rounded-lg shadow-xl shadow-purple-600/30 shadow-md">
      <div class="bg-gray-100 dark:bg-gray-700 rounded-lg p-4">
        <div class="grid grid-cols-2 gap-2">
          <div>
            <span class="bg-gradient-to-r from-purple-500 to-purple-600 bg-clip-text text-4xl font-bold text-transparent">
              {SEC_Node.display_equipment_id(@node)}
            </span>

            <div class="grid grid-cols-2 gap-2 mt-2">
              <div>
                <ul class="mt-2 text-sm font-medium">
                  <.property
                    prop_key="Description"
                    class="border-4 border-zinc-300 dark:border-zinc-600 bg-gray-200 dark:bg-gray-800 rounded-lg p-2"
                    key_class="text-lg"
                  >
                    <div class="rounded-lg text-base">{SEC_Node.display_description(@node)}</div>
                  </.property>
                </ul>
              </div>
              <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-gray-200 dark:bg-gray-800 rounded-lg p-2 mt-2">
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

              <.property prop_key="Connected at">
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
      <div class="mt-3 bg-gray-100 dark:bg-gray-700 rounded-lg  ">
        <%= for {group_name, modules} <- Enum.sort(@grouped_modules) do %>
          <%= if group_name == nil do %>
            <div class="p-2">
              <%= for module <- modules do %>
                <.dash_module module={module} host={@node.host} port={@node.port} />
              <% end %>
            </div>
          <% else %>
            <div class="p-2 mt-4 border-4 border-stone-400 dark:border-stone-500 rounded-lg">
              <h3 class="text-2xl font-semibold m-2 text-stone-400 dark:text-stone-400">
                {Util.display_name(group_name)}
              </h3>

              <%= for module <- modules do %>
                <.dash_module
                  module={module}
                  host={@node.host}
                  port={@node.port}
                  n_modules={@n_modules}
                />
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true
  attr :node_state, :atom, required: true
  attr :values, :map, required: true
  attr :node_id_str, :string, required: true

  def module_indicators(assigns) do
    assigns =
      assign_new(assigns, :node_id_str, fn ->
        "#{to_string(assigns.node.host)}:#{assigns.node.port}"
      end)

    ~H"""
    <div class="flex-none  p-3  mt-4  bg-gray-50 text-medium text-gray-500 dark:text-gray-400 dark:bg-gray-900 rounded-lg">
      <span class="text-lg font-bold  text-black dark:text-white ">Module Status:</span>
      <ul class="mt-1 space-y space-y-2 text-sm font-medium">
        <%= for module <- @node.modules do %>
          <li class=" flex-1 min-w-full">
            <.live_component
              module={ModuleIndicator}
              id={"module_indicator:" <> @node_id_str <>":" <> module.name}
              host={@node.host}
              port={@node.port}
              module_name={module.name}
              highest_if_class={module.highest_interface_class}
              status_param={Module.get_parameter(module, "status")}
              node_state={@node_state}
              indicator_select={:outer}
            />
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  attr :module, :map, required: true
  attr :host, :string, required: true
  attr :port, :integer, required: true
  attr :n_modules, :integer, default: 0

  def dash_module(assigns) do
    grouped_parameters = Enum.group_by(assigns.module.parameters, &(&1.group || nil))
    grouped_commands = Enum.group_by(assigns.module.commands, &(&1.group || nil))

    base_class = assigns.module.highest_interface_class
    styles = get_class_styles(base_class)

    assigns =
      assigns
      |> assign(:grouped_parameters, grouped_parameters)
      |> assign(:grouped_commands, grouped_commands)
      |> assign(:base_class, base_class)
      |> assign(:styles, styles)
      |> assign_new(:node_id_str, fn -> "#{to_string(assigns.host)}:#{assigns.port}" end)

    ~H"""
    <div class="flex  items-start">
      <.accordion
        id={@module.name <> to_string(@module.id)}
        class={"w-3/4  flex-1 h-auto mt-3 p-2 #{@styles.bg} rounded-lg shadow-md hover:shadow-lg border-l-4 #{@styles.border}"}
      >
        <:trigger class="text-left">
          <!-- Module Name with Interface Class Icon -->
          <div class="mb-4 flex items-center">
            <span class="text-2xl font-bold text-gray-800 dark:text-white">
              {Module.display_name(@module)}
            </span>
            <%= if @base_class do %>
              <span class={" font-bold text-gray-800 dark:text-white text-sm ml-2 px-2 py-1 mb-1 rounded-full #{@styles.header_bg}"}>
                {@base_class}
              </span>
            <% end %>
          </div>

    <!-- Module Properties -->
          <div class="flex">
            <div class="w-3/4 mr-2 border-4 border-zinc-300 dark:border-zinc-600 bg-white/50 dark:bg-gray-800/60 rounded-lg p-4">
              <ul class="text-sm text-gray-700 dark:text-gray-300 space-y-2">
                <.property
                  prop_key="Description"
                  key_class="text-gray-700 dark:text-gray-300 text-lg font-bold"
                  value_class="text-lg font-semibold"
                >
                  {@module.description}
                </.property>
                <.property
                  prop_key="Interface Classes"
                  key_class="text-gray-600 dark:text-gray-400 font-semibold"
                >
                  {@module.interface_classes |> Enum.join(", ")}
                </.property>

    <!-- ...existing module properties... -->
                <%= if @module.implementor do %>
                  <.property
                    prop_key="Implementor"
                    key_class="text-gray-600 dark:text-gray-400 font-semibold"
                  >
                    {@module.implementor}
                  </.property>
                <% end %>

                <%= if @module.meaning do %>
                  <.property
                    prop_key="Meaning"
                    key_class="text-gray-600 dark:text-gray-400 font-semibold"
                  >
                    {inspect(@module.meaning)}
                  </.property>
                <% end %>

                <%= for {property_name, property_value} <- @module.custom_properties do %>
                  <.property
                    prop_key={String.replace_prefix(property_name, "_", "")}
                    key_class="text-gray-600 dark:text-gray-400 font-semibold"
                  >
                    {inspect(property_value)}
                  </.property>
                <% end %>
              </ul>
            </div>
            <%= if Module.has_status?(@module) do %>
              <div class="w-1/4 border-4 border-zinc-300 dark:border-zinc-600 bg-white/50 dark:bg-gray-800/60 rounded-lg p-3">
                <.live_component
                  module={ModuleIndicator}
                  id={"module_indicator_mod:"<> @node_id_str <>":"<> @module.name}
                  host={@host}
                  port={@port}
                  module_name={@module.name}
                  highest_if_class={@module.highest_interface_class}
                  status_param={Module.get_parameter(@module, "status")}
                  node_state={:initialized}
                  ,
                  indicator_select={:inner}
                />
              </div>
            <% end %>
          </div>

          <%= cond  do %>
            <% Module.has_parameter?(@module, "value") && Module.has_parameter?(@module, "target")-> %>
              <div class="grid grid-cols-[auto_1fr] items-center">
                <div class="p-2 mt-2 text-lg font-bold text-gray-800 dark:text-white">
                  Value:
                </div>
                <.live_component
                  module={ParameterValueDisplay}
                  id={"module_dash:"<> @node_id_str <>":" <> @module.name <> ":value"}
                  class=""
                  host={@host}
                  port={@port}
                  location="module_dash"
                  module_name={@module.name}
                  parameter={Module.get_parameter(@module, "value")}
                />

                <div class="p-2 mt-2 text-lg font-bold text-gray-800 dark:text-white">
                  Target:
                </div>
                <.live_component
                  module={ParameterValueDisplay}
                  id={"module_dash:"<> @node_id_str <>":" <> @module.name <> ":target"}
                  class=""
                  host={@host}
                  port={@port}
                  module_name={@module.name}
                  location="module_dash"
                  parameter={Module.get_parameter(@module, "target")}
                />


              </div>
            <% Module.has_parameter?(@module, "value") -> %>
              <div class="grid grid-cols-[auto_1fr]  items-center">
                <div class="p-2 mt-2 text-lg font-bold text-gray-800 dark:text-white">
                  Value:
                </div>
                <.live_component
                  module={ParameterValueDisplay}
                  id={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":value"}
                  class=""
                  host={@host}
                  port={@port}
                  location="module_dash"
                  module_name={@module.name}
                  parameter={Module.get_parameter(@module, "value")}
                />
              </div>
          <% end %>
          <%= if @module.commands != [] do %>
          <div class = "flex gap-2 mt-2 p-2 items-center rounded-lg bg-zinc-300/40 dark:bg-zinc-600/40">

            <%= for command <- @module.commands do %>
              <button class = "font-mono text-gray-300 font-semibold pr-4 pl-4 bg-zinc-600 dark:bg-zinc-800 rounded-lg p-1 border border-stone-500 hover:bg-zinc-700 dark:hover:bg-zinc-700">
               {Util.display_name(command.name)}
              </button>
            <% end %>

          </div>
          <% end %>

        </:trigger>
        <:panel class="">
          <!-- Parameters -->
          <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-white/50 dark:bg-gray-800/60 rounded-lg p-4 mt-4">
            <h3 class="text-lg font-bold text-gray-800 dark:text-white mb-2">Parameters:</h3>
            <%= for {group_name, parameters} <- Enum.sort(@grouped_parameters) do %>
              <%= if group_name == nil do %>
                <div class="mt-4 border-l-4 border-transparent pl-4">
                  <%= for parameter <- parameters do %>
                    <.new_dash_parameter
                      host={@host}
                      port={@port}
                      node_id_str={@node_id_str}
                      module_name={@module.name}
                      parameter={parameter}
                    />
                  <% end %>
                </div>
              <% else %>
                <div class="mt-4 border-l-4 border-gray-500 pl-4">
                  <h4 class="text-xl font-semibold mb-2 text-gray-800 dark:text-white">
                    {Util.display_name(group_name)}
                  </h4>
                  <%= for parameter <- parameters do %>
                    <.new_dash_parameter
                      host={@host}
                      port={@port}
                      node_id_str={@node_id_str}
                      module_name={@module.name}
                      parameter={parameter}
                    />
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>

    <!-- Commands -->
          <%= if @module.commands != [] do %>
            <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-white/50 dark:bg-gray-800/60 rounded-lg p-4 mt-4">
              <h3 class="text-lg font-bold text-gray-800 dark:text-white mb-2">Commands:</h3>
              <%= for {group_name, commands} <- Enum.sort(@grouped_commands) do %>
                <%= if group_name == nil do %>
                  <div class="mt-4 border-l-4 border-transparent pl-4">
                    <%= for command <- commands do %>
                      <.dash_command command={command} />
                    <% end %>
                  </div>
                <% else %>
                  <div class="mt-4 border-l-4 border-gray-500 pl-4">
                    <h4 class="text-xl font-semibold mb-2 text-gray-800 dark:text-white">
                      {Util.display_name(group_name)}
                    </h4>
                    <%= for command <- commands do %>
                      <.dash_command command={command} />
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </:panel>
      </.accordion>

      <%= if @n_modules < 20 do %>
        <.live_component
          module={SecopServiceWeb.Components.HistoryDB}
          id={"module-plot:" <> to_string(@module.name)}
          secop_obj={@module}
          class="w-3/5 p-4 hidden xl:block"
        />
      <% end %>
    </div>
    """
  end

  attr :parameter, :map, required: true
  attr :host, :string, required: true
  attr :port, :integer, required: true
  attr :module_name, :string, required: true
  attr :node_id_str, :string, required: true

  def new_dash_parameter(assigns) do
    ~H"""
    <!-- Parameter Name -->
    <div class="mb-4 bg-gray-300 dark:bg-gray-700 rounded-lg p-4 shadow-md">
      <div class="flex justify-between">
        <div class="text-xl font-bold text-gray-800 dark:text-white">
          {Util.display_name(@parameter.name)}:
        </div>
        <div class="flex text-sm pt-1 ">
          <div class="ml-2 px-2 py-0.5 rounded-full bg-white/75 dark:bg-gray-800/75 font-mono">
            {@parameter.datainfo["type"]}
          </div>
          <%= if @parameter.readonly do %>
            <div class="ml-2 px-2 py-0.5 rounded-full bg-white/75 dark:bg-gray-800/75 font-mono">
              r
            </div>
          <% else %>
            <div class="ml-2 px-2 py-0.5 rounded-full bg-white/75 dark:bg-gray-800/75 font-mono">
              r/w
            </div>
          <% end %>
        </div>
      </div>
      <ul class="mt-2 text-sm text-gray-700 dark:text-gray-300">
        <!-- Description -->
        <.property
          prop_key="Description"
          class=""
          key_class="text-gray-700 dark:text-gray-300 text-sm font-bold"
        >
          {@parameter.description}
        </.property>

    <!-- Optional Properties -->
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
          <.property
            prop_key={String.replace_prefix(property_name, "_", "")}
            key_class="text-gray-600 dark:text-gray-400 font-semibold"
          >
            {inspect(property_value)}
          </.property>
        <% end %>
      </ul>

      <.live_component
        module={ParameterValueDisplay}
        id={"parameter_value:"<> @node_id_str <>":" <> @module_name <> ":" <> @parameter.name}
        class=""
        host={@host}
        port={@port}
        location="parameter_value"
        module_name={@module_name}
        parameter={@parameter}
      />
    </div>
    """
  end

  attr :command, :map, required: true

  def dash_command(assigns) do
    ~H"""
    <div class="mb-4 bg-gray-300 dark:bg-gray-700 rounded-lg p-4 shadow-md">

    <!-- Parameter Name -->
      <div>
        <span class="text-xl font-bold text-gray-800 dark:text-white">
          {Util.display_name(@command.name)}:
        </span>
        <ul class="mt-2 text-sm text-gray-700 dark:text-gray-300">
          <!-- Description -->
          <.property
            prop_key="Description"
            class="rounded-lg bg-gray-2 bg-gray-200 dark:bg-gray-600 mb-2 p-2"
            key_class="text-gray-700 dark:text-gray-300 text-sm font-bold"
          >
            {@command.description}
          </.property>

    <!-- Optional Properties -->
          <%= if @command.group do %>
            <.property prop_key="Group" key_class="text-gray-600 dark:text-gray-400 font-semibold">
              {@command.group}
            </.property>
          <% end %>

          <%= if @command.visibility do %>
            <.property
              prop_key="Visibility"
              key_class="text-gray-600 dark:text-gray-400 font-semibold"
            >
              {@command.visibility}
            </.property>
          <% end %>

          <%= if @command.meaning do %>
            <.property prop_key="Meaning" key_class="text-gray-600 dark:text-gray-400 font-semibold">
              {inspect(@command.meaning)}
            </.property>
          <% end %>

          <%= if @command.checkable do %>
            <.property prop_key="Checkable" key_class="text-gray-600 dark:text-gray-400 font-semibold">
              {@command.checkable}
            </.property>
          <% end %>

    <!-- Custom Properties -->
          <%= for {property_name, property_value} <- @command.custom_properties do %>
            <.property
              prop_key={String.replace_prefix(property_name, "_", "")}
              key_class="text-gray-600 dark:text-gray-400 font-semibold"
            >
              {inspect(property_value)}
            </.property>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end
end
