defmodule SecopServiceWeb.DashboardComponents do
  use Phoenix.Component

  alias SecopService.Sec_Nodes.SEC_Node
  alias SecopService.Sec_Nodes.Module

  alias SecopService.Util
  alias Jason
  alias SecopServiceWeb.Components.ModuleIndicator
  alias SecopServiceWeb.Components.ParameterValueDisplay
  alias SecopServiceWeb.Components.CommandDisplay

  import SECoPComponents
  import SecopServiceWeb.BrowseComponents
  import SecopServiceWeb.Components.ParameterFormFieldComponents
  import SecopServiceWeb.CoreComponents

  attr :node, :map, required: true
  attr :state_map, :map, required: true

  def dash_sec_node(assigns) do
    grouped_modules = Enum.group_by(assigns.node.modules, &(&1.group || nil)) |> Enum.sort()

    assigns =
      assign(assigns, :grouped_modules, grouped_modules)
      |> assign(:n_modules, length(assigns.node.modules))

    ~H"""
    <div class="card bg-base-200 flex-1 mt-4 ml-3 p-3  ">
      <div class="card bg-base-100 card-border border-base-300 card-sm p-4 ">
        <div class="grid grid-cols-2 gap-2">
          <div>
            <.node_title check_result={@node.check_result} equipment_id={@node.equipment_id} />

            <div class="grid grid-cols-2 gap-2 mt-2">
              <div class="card bg-neutral text-neutral-content card-sm p-3 overflow-hidden">
                <ul class="text-sm font-medium">
                  <.property
                    prop_key="Description"

                    key_class="text-lg"
                  >
                    <div class="">{SEC_Node.display_description(@node)}</div>
                  </.property>
                </ul>
              </div>
              <div class="card bg-neutral text-neutral-content card-sm p-3 overflow-hidden">
                <p class="text-lg font-bold ">Node Properties:</p>

                <ul class="text-sm font-medium ">
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
          <div class="relative text-neutral-base overflow-hidden">
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

            <fieldset class="absolute right-0 bottom-0  fieldset bg-base-100 border-base-300 rounded-box border p-4">
              <label class="label">
              <input
                type="checkbox"
                checked={@state_map.active}
                phx-click="toggle-conn-state"
                class="toggle toggle-lg border-warning bg-warning checked:bg-success checked:border-success "
              />
                Async update Messages
              </label>
            </fieldset>




          </div>
        </div>
      </div>

    <!--Modules -->
      <div class="mt-3 card  ">
        <%= for {group_name, modules} <- @grouped_modules do %>
          <div class="collapse  collapse-arrow bg-base-100 border-base-300 border">
            <input
              type="checkbox"
              checked
            />
            <div class="collapse-title font-semibold">
              <%= if group_name == nil do %>
                Ungrouped Modules
              <% else %>
              {Util.display_name(group_name)}
              <% end %>
            </div>
            <div class="collapse-content text-sm">
              <%= for module <- modules do %>
                <.dash_module
                  module={module}
                  host={@node.host}
                  port={@node.port}
                  n_modules={@n_modules}
                  interface_class={module.highest_interface_class}
                />
              <% end %>
            </div>
          </div>



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
    <div class="flex-none  p-3  mt-4  card bg-base-200 ">
      <span class="text-base-content text-lg font-bold">Module Status:</span>
      <ul class="mt-1 space-y space-y-2">
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

  attr :interface_class, :string
  attr :node_id_str, :string, required: true

  slot :parameter_preview, required: true


  def base_module(assigns) do

    grouped_parameters = Enum.group_by(assigns.module.parameters, &(&1.group || nil)) |> Enum.sort()
    grouped_commands = Enum.group_by(assigns.module.commands, &(&1.group || nil)) |> Enum.sort()

    assigns =
      assigns
      |> assign(:styles, get_class_styles(assigns.interface_class))
      |> assign(:grouped_parameters, grouped_parameters)
      |> assign(:grouped_commands, grouped_commands)





    ~H"""
    <div class="flex mt-3 items-stretch gap-3">
      <div class="flex-1">
        <%!-- Module header and interactive elements (outside collapse) --%>
        <div class={["bg-base-100 rounded-t-lg p-4", @styles.bg, @styles.border,"border-t-2 border-l-2 border-r-2"]}>
          <%!-- Module Name with Interface Class Icon --%>
          <div class="mb-2 flex items-center">
            <span class="text-2xl font-bold text-gray-800 dark:text-white">
              {Module.display_name(@module)}
            </span>
            <%= if @interface_class do %>
              <span class={["font-bold text-gray-800 dark:text-white text-sm ml-2 px-2 py-1 mb-1 rounded-full", @styles.header_bg]}>
                {@interface_class}
              </span>
            <% end %>
          </div>

          <%!-- Module Properties --%>
          <div class="flex">
            <div class="card card-border border-4 border-base-100/80 bg-neutral/45 w-3/4 mr-2 p-3">
              <ul class="text-sm text-neutral-content space-y-2">
                <.property
                  prop_key="Description"
                  key_class="text-lg"
                  value_class="text-lg font-semibold text-neutral-content/80"
                >
                  {@module.description}
                </.property>
                <.property
                  prop_key="Interface Classes"
                  key_class="font-semibold"
                >
                  {@module.interface_classes |> Enum.join(", ")}
                </.property>

                <%= if @module.implementor do %>
                  <.property
                    prop_key="Implementor"
                    key_class="font-semibold"
                  >
                    {@module.implementor}
                  </.property>
                <% end %>

                <%= if @module.meaning do %>
                  <.property
                    prop_key="Meaning"
                    key_class="font-semibold"
                  >
                    {inspect(@module.meaning)}
                  </.property>
                <% end %>

                <%= for {property_name, property_value} <- @module.custom_properties, property_name != "_plotly" do %>
                  <.property
                    prop_key={String.replace_prefix(property_name, "_", "")}
                    key_class="font-semibold"
                  >
                    {inspect(property_value)}
                  </.property>
                <% end %>
              </ul>
            </div>
            <%= if Module.has_status?(@module) do %>
              <div class="w-1/4 card card-border border-4 border-base-100/80 bg-neutral/45 p-3 overflow-hidden">
                <.live_component
                  module={ModuleIndicator}
                  id={"module_indicator_mod:"<> @node_id_str <>":"<> @module.name}
                  host={@host}
                  port={@port}
                  module_name={@module.name}
                  highest_if_class={@module.highest_interface_class}
                  status_param={Module.get_parameter(@module, "status")}
                  node_state={:initialized}
                  indicator_select={:inner}
                />
              </div>
            <% end %>


          </div>

          <%!-- Value/Target displays --%>
          {render_slot(@parameter_preview)}


          <%!-- Commands --%>
          <%= if @module.commands != [] do %>
            <div class="flex rounded-lg gap-2 mt-2 p-2 bg-neutral/40">
              <%= for command <- @module.commands do %>
                <.live_component
                  module={CommandDisplay}
                  id={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":" <> command.name}
                  class=""
                  host={@host}
                  port={@port}
                  location="module_dash"
                  module_name={@module.name}
                  command={command}
                  id_str={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":" <> command.name}
                />
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Collapsible section for parameters and commands details --%>
        <div class={["collapse collapse-arrow", @styles.bg, @styles.border, "border-2 rounded-b-lg rounded-t-none "]}>
          <input type="checkbox" />
          <div class="collapse-title text-lg font-semibold text-gray-800 dark:text-white ">
            <.icon name="hero-magnifying-glass" class=" h-5 w-5  mr-1" /> Configuration Parameters & Details
          </div>
          <div class="collapse-content text-sm">
            <%!-- Parameters --%>
            <div class="card border-4 bg-base-200 border-base-100 p-4 mt-4">
              <h3 class="text-lg font-bold text-base-content mb-2">Parameters:</h3>
              <%= for {group_name, parameters} <- @grouped_parameters do %>
                <div class="collapse collapse-arrow bg-base-100 border-base-300 border">
                  <%= if group_name == nil do %>
                    <input type="checkbox" checked />
                  <% else %>
                    <input type="checkbox" />
                  <% end %>
                  <div class="collapse-title font-semibold">
                      <%= if group_name == nil do %>
                            Ungrouped Parameters
                      <% else %>
                            {Util.display_name(group_name)}
                      <% end %>

                  </div>
                  <div class="collapse-content text-sm">
                    <%= for parameter <- parameters do %>
                      <.dash_parameter
                        host={@host}
                        port={@port}
                        node_id_str={@node_id_str}
                        module_name={@module.name}
                        parameter={parameter}
                      />
                    <% end %>
                  </div>
                </div>

              <% end %>
            </div>

            <%!-- Commands --%>
            <%= if @module.commands != [] do %>
              <div class="card border-4 bg-base-200 border-base-100 p-4 mt-4">
                <h3 class="text-lg font-bold text-base-content mb-2">Commands:</h3>
                <%= for {group_name, commands} <- @grouped_commands do %>
                  <div class="collapse collapse-arrow bg-base-100 border-base-300 border ">
                  <%= if group_name == nil do %>
                    <input type="checkbox" checked />
                  <% else %>
                    <input type="checkbox" />
                  <% end %>
                  <div class="collapse-title font-semibold">
                      <%= if group_name == nil do %>
                            Ungrouped Commands
                      <% else %>
                            {Util.display_name(group_name)}
                      <% end %>

                  </div>
                  <div class="collapse-content text-sm ">
                    <%= for command <- commands do %>
                      <.dash_command
                        command={command}
                      />
                    <% end %>
                  </div>
                </div>

                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <%= if @n_modules < 20 do %>
        <.live_component
          module={SecopServiceWeb.Components.HistoryDB}
          id={"module-plot:" <> to_string(@module.name)}
          secop_obj={@module}
          class="w-3/5 hidden xl:block"
        />
      <% end %>
    </div>

    """
  end


  attr :module, :map, required: true
  attr :host, :string, required: true
  attr :port, :integer, required: true
  attr :n_modules, :integer, default: 0
  attr :interface_class, :string

  def dash_module(%{interface_class: "communicator"}=assigns) do

    assigns =
      assigns
      |> assign_new(:node_id_str, fn -> "#{to_string(assigns.host)}:#{assigns.port}" end)

    ~H"""
    <.base_module
      module={@module}
      host={@host}
      port={@port}
      n_modules={@n_modules}
      interface_class={@interface_class}
      node_id_str={@node_id_str}
    >
      <:parameter_preview>
        <div>

        </div>

      </:parameter_preview>


    </.base_module>
    """
  end

  def dash_module(%{interface_class: "readable"}=assigns) do

    assigns =
      assigns
      |> assign_new(:node_id_str, fn -> "#{to_string(assigns.host)}:#{assigns.port}" end)

    ~H"""
    <.base_module
      module={@module}
      host={@host}
      port={@port}
      n_modules={@n_modules}
      interface_class={@interface_class}
      node_id_str={@node_id_str}
    >


      <:parameter_preview>
        <div class="grid grid-cols-[auto_1fr] items-center mt-4">
          <div class="p-2 text-lg font-bold text-neutral-content">
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
            id_str={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":value"}
          />
          </div>

      </:parameter_preview>


    </.base_module>
    """
  end

  def dash_module(%{interface_class: interface_class}=assigns) when interface_class in  ["writable", "drivable"] do
    assigns =
      assigns
      |> assign_new(:node_id_str, fn -> "#{to_string(assigns.host)}:#{assigns.port}" end)

    ~H"""
    <.base_module
      module={@module}
      host={@host}
      port={@port}
      n_modules={@n_modules}
      interface_class={@interface_class}
      node_id_str={@node_id_str}
    >

      <:parameter_preview>
        <div class="grid grid-cols-[auto_1fr] items-center mt-4">
          <div class="p-2 text-lg font-bold text-neutral-content">
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
            id_str={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":value"}
          />

          <div class="p-2 mt-2 text-lg font-bold text-neutral-content">
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
            id_str={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":target"}
          />
        </div>

      </:parameter_preview>


    </.base_module>
    """
  end


  def dash_module(%{interface_class: "acquisition"}=assigns) do

    assigns =
      assigns
      |> assign_new(:node_id_str, fn -> "#{to_string(assigns.host)}:#{assigns.port}" end)

    ~H"""
    <.base_module
      module={@module}
      host={@host}
      port={@port}
      n_modules={@n_modules}
      interface_class={@interface_class}
      node_id_str={@node_id_str}
    >


      <:parameter_preview>
        <div class="grid grid-cols-[auto_1fr] items-center mt-4">
          <div class="p-2 text-lg font-bold text-neutral-content">
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
            id_str={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":value"}
          />
          </div>

      </:parameter_preview>


    </.base_module>
    """
  end

  def dash_module(%{interface_class: "acquisition_channel"}=assigns) do

    assigns =
      assigns
      |> assign_new(:node_id_str, fn -> "#{to_string(assigns.host)}:#{assigns.port}" end)

    ~H"""
    <.base_module
      module={@module}
      host={@host}
      port={@port}
      n_modules={@n_modules}
      interface_class={@interface_class}
      node_id_str={@node_id_str}
    >

      <:parameter_preview>
        <div class="grid grid-cols-[auto_1fr] items-center mt-4">
          <div class="p-2 text-lg font-bold text-neutral-content">
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
            id_str={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":value"}
          />
        </div>

      </:parameter_preview>


    </.base_module>
    """
  end

  def dash_module(%{interface_class: "acquisition_controller"}=assigns) do

    assigns =
      assigns
      |> assign_new(:node_id_str, fn -> "#{to_string(assigns.host)}:#{assigns.port}" end)

    ~H"""
    <.base_module
      module={@module}
      host={@host}
      port={@port}
      n_modules={@n_modules}
      interface_class={@interface_class}
      node_id_str={@node_id_str}
    >


      <:parameter_preview>
        <div></div>
      </:parameter_preview>


    </.base_module>
    """
  end



  attr :module, :map, required: true
  attr :host, :string, required: true
  attr :port, :integer, required: true
  attr :n_modules, :integer, default: 0

  def dash_module_old(assigns) do
    grouped_parameters = Enum.group_by(assigns.module.parameters, &(&1.group || nil)) |> Enum.sort()
    grouped_commands = Enum.group_by(assigns.module.commands, &(&1.group || nil)) |> Enum.sort()

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
    <div class="flex mt-3 items-start">
    <div class="flex-1">
      <%!-- Module header and interactive elements (outside collapse) --%>
      <div class={["bg-base-100 border rounded-t-lg p-4", @styles.bg, @styles.border]}>
        <%!-- Module Name with Interface Class Icon --%>
        <div class="mb-2 flex items-center">
          <span class="text-2xl font-bold text-gray-800 dark:text-white">
            {Module.display_name(@module)}
          </span>
          <%= if @interface_class do %>
            <span class={["font-bold text-gray-800 dark:text-white text-sm ml-2 px-2 py-1 mb-1 rounded-full", @styles.header_bg]}>
              {@interface_class}
            </span>
          <% end %>
        </div>

        <%!-- Module Properties --%>
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

              <%= for {property_name, property_value} <- @module.custom_properties, property_name != "_plotly" do %>
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
                indicator_select={:inner}
              />
            </div>
          <% end %>
        </div>

        <%!-- Value/Target displays --%>
        <%= cond do %>
          <% Module.has_parameter?(@module, "value") && Module.has_parameter?(@module, "target") -> %>
            <div class="grid grid-cols-[auto_1fr] items-center mt-4">
              <div class="p-2 text-lg font-bold text-gray-800 dark:text-white">
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
                id_str={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":value"}
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
                id_str={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":target"}
              />
            </div>
          <% Module.has_parameter?(@module, "value") -> %>
            <div class="grid grid-cols-[auto_1fr] items-center mt-4">
              <div class="p-2 text-lg font-bold text-gray-800 dark:text-white">
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
                id_str={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":value"}
              />
            </div>
          <% true -> %>
            <div></div>
        <% end %>

        <%!-- Commands --%>
        <%= if @module.commands != [] do %>
          <div class="flex gap-2 mt-2 p-2 items-center rounded-lg bg-zinc-300/40 dark:bg-zinc-600/40">
            <%= for command <- @module.commands do %>
              <.live_component
                module={CommandDisplay}
                id={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":" <> command.name}
                class=""
                host={@host}
                port={@port}
                location="module_dash"
                module_name={@module.name}
                command={command}
                id_str={"module_dash:"<> @node_id_str <> ":" <> @module.name <> ":" <> command.name}
              />
            <% end %>
          </div>
        <% end %>
      </div>

      <%!-- Collapsible section for parameters and commands details --%>
      <div class={["collapse collapse-plus bg-base-100 border border-t-0 rounded-b-lg", @styles.bg, @styles.border]}>
        <input type="checkbox" />
        <div class="collapse-title font-semibold text-gray-800 dark:text-white">
          Parameters & Commands Details
        </div>
        <div class="collapse-content text-sm">
          <%!-- Parameters --%>
          <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-white/50 dark:bg-gray-800/60 rounded-lg p-4 mt-4">
            <h3 class="text-lg font-bold text-gray-800 dark:text-white mb-2">Parameters:</h3>
            <%= for {group_name, parameters} <- @grouped_parameters do %>
              <%= if group_name == nil do %>
                <div class="mt-4 border-l-4 border-transparent pl-4">
                  <%= for parameter <- parameters do %>
                    <.dash_parameter
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
                    <.dash_parameter
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

          <%!-- Commands --%>
          <%= if @module.commands != [] do %>
            <div class="border-4 border-zinc-300 dark:border-zinc-600 bg-white/50 dark:bg-gray-800/60 rounded-lg p-4 mt-4">
              <h3 class="text-lg font-bold text-gray-800 dark:text-white mb-2">Commands:</h3>
              <%= for {group_name, commands} <- @grouped_commands do %>
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
        </div>
      </div>
    </div>

    <%= if @n_modules < 20 do %>
      <.live_component
        module={SecopServiceWeb.Components.HistoryDB}
        id={"module-plot:" <> to_string(@module.name)}
        secop_obj={@module}
        class="w-3/5 hidden xl:block"
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

  def dash_parameter(assigns) do


    ~H"""
    <!-- Parameter Name -->
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

        <div class="flex text-sm text-base-content pt-1 ">
          <div class="ml-2 px-2 py-0.5 rounded-full bg-base-100 font-mono">
            {@parameter.datainfo["type"]}
          </div>
          <%= if @parameter.readonly do %>
            <div class="ml-2 px-2 py-0.5 rounded-full bg-base-100 font-mono">
              r
            </div>
          <% else %>
            <div class="ml-2 px-2 py-0.5 rounded-full bg-base-100 font-mono">
              r/w
            </div>
          <% end %>
        </div>
      </div>
      <ul class="mt-2 text-sm text-neutral-content/80">
        <!-- Description -->
        <.property
          prop_key="Description"
          class=""
          key_class="text-neutral-content/80 text-sm font-bold"
        >
          {@parameter.description}
        </.property>

    <!-- Optional Properties -->
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

    <!-- Custom Properties -->
        <%= for {property_name, property_value} <- @parameter.custom_properties do %>
          <.property
            prop_key={String.replace_prefix(property_name, "_", "")}
            key_class="text-neutral-content/80 font-semibold"
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
        id_str={"parameter_value:"<> @node_id_str <> ":" <> @module_name <> ":" <> @parameter.name}
      />
    </div>
    """
  end

  attr :command, :map, required: true

  def dash_command(assigns) do
    ~H"""
    <div class="card mb-4 bg-neutral p-4 shadow-md">

    <!-- Parameter Name -->
      <div>
        <div class="flex ">
          <div>
            <.datainfo_tooltip datainfo={@command.datainfo} position="tooltip-right" />
          </div>

          <div class="text-lg font-bold text-neutral-content">
            {Util.display_name(@command.name)}:
          </div>
        </div>
        <ul class="mt-2 text-sm text-neutral-content/80">
          <!-- Description -->
          <.property
            prop_key="Description"
            class="card bg-neutral-content/20 mb-2 p-2"
            key_class="text-neutral-content text-sm font-bold"
          >
            {@command.description}
          </.property>

          <!-- Optional Properties -->
          <%= if @command.group do %>
            <.property prop_key="Group" key_class="text-neutral-content font-semibold">
              {@command.group}
            </.property>
          <% end %>

          <%= if @command.visibility do %>
            <.property
              prop_key="Visibility"
              key_class="text-neutral-content font-semibold"
            >
              {@command.visibility}
            </.property>
          <% end %>

          <%= if @command.meaning do %>
            <.property prop_key="Meaning" key_class="text-neutral-content font-semibold">
              {inspect(@command.meaning)}
            </.property>
          <% end %>

          <%= if @command.checkable do %>
            <.property prop_key="Checkable" key_class="text-neutral-content font-semibold">
              {@command.checkable}
            </.property>
          <% end %>

          <!-- Custom Properties -->
          <%= for {property_name, property_value} <- @command.custom_properties do %>
            <.property
              prop_key={String.replace_prefix(property_name, "_", "")}
              key_class="text-neutral-content font-semibold"
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
