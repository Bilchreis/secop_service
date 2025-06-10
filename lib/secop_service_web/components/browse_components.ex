defmodule SecopServiceWeb.BrowseComponents do
  use Phoenix.Component

  alias SecopService.Sec_Nodes.SEC_Node
  alias SecopService.Sec_Nodes.Module

  alias SecopService.Util
  alias Jason

  import SecopServiceWeb.CoreComponents

  import SECoPComponents

  attr :node, :map, required: true

  def sec_node_view(assigns) do
    grouped_modules = Enum.group_by(assigns.node.modules, &(&1.group || nil))

    assigns = assign(assigns, :grouped_modules, grouped_modules)

    ~H"""
    <div class="bg-gray-200 dark:bg-gray-800 dark:text-gray-300 shadow-xl shadow-purple-600/30  p-4 rounded-lg shadow-md">
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
              <.module module={module} module_descr={@node.describe_message["modules"][module.name]} />
            <% end %>
          <% else %>
            <div class="mb-6 border-l-4 border-t-4 border-stone-400 dark:border-stone-400 pl-4 rounded-lg">
              <h3 class="text-xl font-semibold m-2 text-stone-500 dark:text-stone-400">
                {Util.display_name(group_name)}
              </h3>

              <%= for module <- modules do %>
                <.module
                  module={module}
                  module_descr={@node.describe_message["modules"][module.name]}
                />
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

  attr :enum, :map, required: true

  def enum(assigns) do
    ordered_members = assigns.enum["members"] |> Enum.sort_by(fn {_, v} -> v end)

    assigns =
      assigns
      |> assign(:ordered_members, ordered_members)

    ~H"""
    <div class="space-y-4">
      <!-- Badge View -->
      <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden mt-2 inline-flex">
        <div class="p-4 flex flex-wrap gap-2">
          <%= for {name, value} <- @ordered_members do %>
            <div class="flex items-center px-3 py-1.5 rounded-md border bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200 border-gray-300 dark:border-gray-600">
              <span class="font-mono text-sm font-medium">{name}</span>
              <span class="ml-2 px-2 py-0.5 rounded-full bg-white/75 dark:bg-gray-800/75 text-xs font-mono">
                {value}
              </span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp get_color_class(code) do
    color_classes = %{
      :disabled =>
        "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200 border-gray-300 dark:border-gray-600",
      :idle =>
        "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-100 border-green-200 dark:border-green-800",
      :warn =>
        "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-100 border-yellow-200 dark:border-yellow-800",
      :busy =>
        "bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-100 border-orange-200 dark:border-orange-800",
      :error =>
        "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-100 border-red-200 dark:border-red-800"
    }

    state =
      cond do
        code < 99 -> :disabled
        code < 199 -> :idle
        code < 299 -> :warn
        code < 399 -> :busy
        code < 499 -> :error
        true -> :disabled
      end

    {state, color_classes[state]}
  end

  attr :status_tuple, :map, required: true

  def status_tuple(assigns) do
    ordered_members =
      assigns.status_tuple["members"]
      |> Enum.at(0)
      |> Map.get("members")
      |> Enum.sort_by(fn {_, v} -> v end)
      |> Enum.map(fn {name, value} ->
        {name, value, get_color_class(value)}
      end)

    assigns =
      assigns
      |> assign(:ordered_members, ordered_members)

    ~H"""
    <div class="">
      <!-- Badge View -->
      <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden mt-2 inline-flex">
        <div class="p-4 flex flex-wrap gap-2">
          <%= for {name, value, {_state, color_class}} <- @ordered_members do %>
            <div class={["flex items-center px-3 py-1.5 rounded-md border", color_class]}>
              <span class="font-mono text-sm font-medium">{name}</span>
              <span class="ml-2 px-2 py-0.5 rounded-full bg-white/75 dark:bg-gray-800/75 text-xs font-mono">
                {value}
              </span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :module, :map, required: true
  attr :module_descr, :map, required: true

  def module(assigns) do
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

    ~H"""
    <div class="flex  items-start">
      <.accordion
        id={@module.name <> to_string(@module.id)}
        class={"w-3/4  flex-1 h-auto mt-3 p-4 #{@styles.bg} rounded-lg shadow-md hover:shadow-lg border-l-4 #{@styles.border}"}
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
          <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-white/50 dark:bg-gray-800/60 rounded-lg p-4">
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

              <%= if @module.group do %>
                <.property prop_key="Group" key_class="text-gray-600 dark:text-gray-400 font-semibold">
                  {@module.group}
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
        </:trigger>
        <:panel class="">
          <!-- Parameters -->
          <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-white/50 dark:bg-gray-800/60 rounded-lg p-4 mt-4">
            <h3 class="text-lg font-bold text-gray-800 dark:text-white mb-2">Parameters:</h3>
            <%= for {group_name, parameters} <- Enum.sort(@grouped_parameters) do %>
              <%= if group_name == nil do %>
                <div class="mt-4 border-l-4 border-transparent pl-4">
                  <%= for parameter <- parameters do %>
                    <.parameter
                      parameter={parameter}
                      parameter_descr={@module_descr["accessibles"][parameter.name]}
                    />
                  <% end %>
                </div>
              <% else %>
                <div class="mt-4 border-l-4 border-gray-500 pl-4">
                  <h4 class="text-xl font-semibold mb-2 text-gray-800 dark:text-white">
                    {Util.display_name(group_name)}
                  </h4>
                  <%= for parameter <- parameters do %>
                    <.parameter
                      parameter={parameter}
                      parameter_descr={@module_descr["accessibles"][parameter.name]}
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
                      <.command
                        command={command}
                        command_descr={@module_descr["accessibles"][command.name]}
                      />
                    <% end %>
                  </div>
                <% else %>
                  <div class="mt-4 border-l-4 border-gray-500 pl-4">
                    <h4 class="text-xl font-semibold mb-2 text-gray-800 dark:text-white">
                      {Util.display_name(group_name)}
                    </h4>
                    <%= for command <- commands do %>
                      <.command
                        command={command}
                        command_descr={@module_descr["accessibles"][command.name]}
                      />
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </:panel>
      </.accordion>

      <.live_component
        module={SecopServiceWeb.Components.HistoryDB}
        id={"module-plot-" <> to_string(@module.id)}
        secop_obj={@module}
        class="w-3/5 p-4 "
      />
    </div>
    """
  end

  # Helper function to get class-specific styles
  def get_class_styles(interface_class) do
    case interface_class do
      "communicator" ->
        %{
          border: "border-blue-500 dark:border-blue-600/40",
          bg:
            "bg-gradient-to-r from-blue-200 to-blue-300 dark:from-blue-900/30 dark:to-blue-900/40",
          header_bg: "bg-blue-300 dark:bg-blue-800/50",
          icon: "hero-chat-bubble-left-right"
        }

      "readable" ->
        %{
          border: "border-green-500 dark:border-green-600/40",
          bg:
            "bg-gradient-to-r from-green-200 to-green-300 dark:from-green-900/30 dark:to-green-900/40",
          header_bg: "bg-green-300 dark:bg-green-800/50",
          icon: "hero-eye"
        }

      "writable" ->
        %{
          border: "border-amber-500 dark:border-amber-600/40",
          bg:
            "bg-gradient-to-r from-amber-200 to-amber-300 dark:from-amber-900/30 dark:to-amber-900/40",
          header_bg: "bg-amber-300 dark:bg-amber-800/50",
          icon: "hero-pencil-square"
        }

      "drivable" ->
        %{
          border: "border-purple-500 dark:border-purple-600/40",
          bg:
            "bg-gradient-to-r from-purple-200 to-purple-300 dark:from-purple-900/30 dark:to-purple-900/40",
          header_bg: "bg-purple-300 dark:bg-purple-800/50",
          icon: "hero-cog"
        }

      "measurable" ->
        %{
          border: "border-blue-500 dark:border-blue-600/40",
          bg:
            "bg-gradient-to-r from-blue-200 to-blue-300 dark:from-blue-900/30 dark:to-blue-900/40",
          header_bg: "bg-blue-300 dark:bg-blue-800/50",
          icon: "hero-clock"
        }

      _ ->
        %{
          border: "border-gray-500 dark:border-gray-600/40",
          bg: "bg-gray-200 dark:bg-gray-800/50",
          header_bg: "bg-gray-300 dark:bg-gray-700/50",
          icon: "hero-cube"
        }
    end
  end

  attr :parameter, :map, required: true
  attr :parameter_descr, :map, required: true

  def parameter(assigns) do
    parameter_pretty = Jason.encode!(assigns.parameter_descr, pretty: true)

    assigns =
      assigns
      |> assign(:parameter_pretty, parameter_pretty)

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
        
    <!-- Readonly -->
        <.property prop_key="Readonly" key_class="text-gray-600 dark:text-gray-400 font-semibold">
          {@parameter.readonly}
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

        <%= if @parameter.datainfo["type"] == "enum" do %>
          <.property
            prop_key="Enum Members"
            key_class="text-gray-600 dark:text-gray-400 font-semibold"
          >
            <.enum enum={@parameter.datainfo} />
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

        <%= if @parameter.name == "status" do %>
          <.status_tuple status_tuple={@parameter.datainfo} />
        <% end %>
      </ul>

      <.accordion
        id={@parameter.name <> to_string(@parameter.id)}
        class="mt-3 bg-gray-200 dark:bg-gray-600 dark:hover:bg-gray-500 rounded-lg  "
      >
        <:trigger class="p-2  text-left text-sm">
          <div class="flex flex-row">
            <.icon name="hero-information-circle" class=" h-5 w-5 flex-none mr-1" />
            <span>JSON Description: </span>
          </div>
        </:trigger>
        <:panel class="p-4 ">
          <pre class="whitespace-pre-wrap break-words max-h-[60vh] overflow-y-auto bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200 font-mono text-xs p-2 rounded-lg ">
            {@parameter_pretty}
          </pre>
        </:panel>
      </.accordion>
    </div>
    """
  end

  attr :command, :map, required: true
  attr :command_descr, :map, required: true

  def command(assigns) do
    datainfo_pretty = Jason.encode!(assigns.command.datainfo, pretty: true)

    assigns =
      assigns
      |> assign(:datainfo_pretty, datainfo_pretty)

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
      
    <!-- Datainfo -->
      <div>
        <.accordion
          id={@command.name <> to_string(@command.id)}
          class="mt-3 bg-gray-200 dark:bg-gray-600 dark:hover:bg-gray-500 rounded-lg  "
        >
          <:trigger class="p-2  text-left text-sm">
            <div class="flex flex-row">
              <div class="p-1">
                <.icon name="hero-information-circle" class=" h-5 w-5 flex-none" />
              </div>
              <div class="p-1">
                <span>Datainfo </span>
              </div>
            </div>
          </:trigger>
          <:panel class="p-4 ">
            <pre class="whitespace-pre-wrap break-words max-h-[60vh] overflow-y-auto bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200 font-mono text-xs p-2 rounded-lg ">
                {@datainfo_pretty}
              </pre>
          </:panel>
        </.accordion>
      </div>
    </div>
    """
  end
end
