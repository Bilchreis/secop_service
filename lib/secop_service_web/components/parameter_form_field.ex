defmodule SecopServiceWeb.Components.ParameterFormFieldComponents do

  use Phoenix.Component
  import SecopServiceWeb.CoreComponents


  attr :datainfo, :map, required: true
  attr :modal_form, :map, required: true
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 1
  attr :path, :list, default: ["value"]
  attr :parameter_id, :string, required: true
  attr :location, :string, required: true

  def input_parameter(assigns) do
    ~H"""
    <%= case @datainfo["type"] do %>
      <% "struct" -> %>
        <.input_struct datainfo={@datainfo} location={@location} modal_form={@modal_form} depth={@depth} max_depth={@max_depth} path={@path} parameter_id={@parameter_id} />
      <% "tuple" -> %>
        <.input_tuple datainfo={@datainfo} location={@location} modal_form={@modal_form} depth={@depth} max_depth={@max_depth} path={@path} parameter_id={@parameter_id} />
      <% type when type in ["double", "int", "scaled"] -> %>
        <.input_numeric datainfo={@datainfo} location={@location} modal_form={@modal_form} depth={@depth} max_depth={@max_depth} path={@path} parameter_id={@parameter_id} />
      <% "bool" -> %>
        <.input_bool datainfo={@datainfo} location={@location} modal_form={@modal_form} depth={@depth} max_depth={@max_depth} path={@path} parameter_id={@parameter_id} />
      <% "enum" -> %>
        <.input_enum datainfo={@datainfo} location={@location} modal_form={@modal_form} depth={@depth} max_depth={@max_depth} path={@path} parameter_id={@parameter_id} />
      <% "array" -> %>
        <.input_array datainfo={@datainfo} location={@location} modal_form={@modal_form} depth={@depth} max_depth={@max_depth} path={@path} parameter_id={@parameter_id} />
      <% "string" -> %>
        <.input_string datainfo={@datainfo} location={@location} modal_form={@modal_form} depth={@depth} max_depth={@max_depth} path={@path} parameter_id={@parameter_id} />
      <% "blob" -> %>
        blob
      <% "matrix" -> %>
        matrix
      <% _ -> %>
        unknown type
    <% end %>
    """
  end

  attr :datainfo, :map, required: true
  attr :modal_form, :map, required: true
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 1
  attr :path, :list, default: ["value"]
  attr :parameter_id, :integer, required: true
  attr :location, :string, required: true

  def input_numeric(assigns) do

    assigns = assigns
      |> assign(:field, Enum.join(assigns.path, "."))

    ~H"""
      <.input
        name={@field}
        type="number"
        field={@modal_form[@field]}
        value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
        phx-debounce="500"
        class="bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 font-mono text-gray-900 dark:text-gray-200 opacity-100"
      />

    """
  end

  attr :datainfo, :map, required: true
  attr :modal_form, :map, required: true
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 1
  attr :path, :list, default: ["value"]
  attr :parameter_id, :integer, required: true
  attr :location, :string, required: true


  def input_string(assigns) do
    assigns = assigns
      |> assign(:field, Enum.join(assigns.path, "."))

    ~H"""
      <.input
        name={@field}
        type="text"
        field={@modal_form[@field]}
        value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
        phx-debounce="500"
        class="flex-1 max-h-80 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
      />


    """
  end

  attr :datainfo, :map, required: true
  attr :modal_form, :map, required: true
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 1
  attr :path, :list, default: ["value"]
  attr :parameter_id, :integer, required: true
  attr :location, :string, required: true


  def input_bool(assigns) do
    assigns = assigns
      |> assign(:field, Enum.join(assigns.path, "."))

    ~H"""
      <.input
        name={@field}
        type="checkbox"
        field={@modal_form[@field]}
        value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
        phx-debounce="500"
        class="flex-1 max-h-80 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
      />
    """
  end

  attr :datainfo, :map, required: true
  attr :modal_form, :map, required: true
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 1
  attr :path, :list, default: ["value"]
  attr :parameter_id, :string, required: true
  attr :location, :string, required: true

  def input_enum(assigns) do



    select_options = assigns.datainfo["members"]

    assigns = assigns
      |> assign(:field, Enum.join(assigns.path, "."))
      |> assign(:options, select_options)
      |> assign(:popover_id, "popover-" <> assigns.location <> "-" <> assigns.parameter_id <> Enum.join(assigns.path, "-"))
      |> assign(:pretty_datainfo, Jason.encode!(assigns.datainfo, pretty: true))

    ~H"""

      <.input
        name={@field}
        type="select"
        options={@options}
        field={@modal_form[@field]}
        value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
        phx-debounce="500"
        data-popover-target={@popover_id}

        class="bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 font-mono text-gray-900 dark:text-gray-200 opacity-100"
      />
    """
  end

  attr :datainfo, :map, required: true
  attr :modal_form, :map, required: true
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 1
  attr :path, :list, default: ["value"]
  attr :parameter_id, :integer, required: true
  attr :location, :string, required: true


  def input_struct(assigns) do

    assigns = assigns
      |> assign(:field, Enum.join(assigns.path, "."))
      |> assign(:grid_cols, if(length(Map.to_list(assigns.datainfo["members"])) > 6, do: "grid-cols-3", else: "grid-cols-1"))

    ~H"""
    Struct:
    <%= if @depth >= @max_depth do %>
      <.input
        name={@field}
        type="text"
        field={@modal_form[@field]}
        value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
        phx-debounce="500"
        class="flex-1 max-h-80 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
      />
    <% else %>
      <div class={"grid #{@grid_cols} gap-x-2 gap-y-2 items-center border-stone-500 dark:border-stone-500 rounded-lg  border p-2"}>
        <%= for {member_name, member_info} <- @datainfo["members"] do %>
          <div class="flex items-center gap-2">
            <div class="flex-1 font-semibold text-gray-700 dark:text-gray-300 text-right">
              {member_name}:
            </div>
            <div class="flex-1">
              <.input_parameter
                datainfo={member_info}
                path={@path ++ [member_name]}
                modal_form={@modal_form}
                depth={@depth + 1}
                max_depth={@max_depth}
                parameter_id={@parameter_id}
                location={@location}
              />
            </div>
          </div>
        <% end %>
      </div>
    <% end %>

    """
  end

  attr :datainfo, :map, required: true
  attr :modal_form, :map, required: true
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 1
  attr :path, :list, default: ["value"]
  attr :parameter_id, :integer, required: true
  attr :location, :string, required: true


  def input_tuple(assigns) do

    assigns = assigns
      |> assign(:field, Enum.join(assigns.path, "."))
      |> assign(:grid_cols, if(length(assigns.datainfo["members"]) > 6, do: "grid-cols-3", else: "grid-cols-1"))

    ~H"""
    Tuple:
    <%= if @depth >= @max_depth do %>
      <.input
        name={@field}
        type="text"
        field={@modal_form[@field]}
        value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
        phx-debounce="500"
        class="flex-1 max-h-80 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
      />
    <% else %>
      <div class={"grid #{@grid_cols} gap-x-2 gap-y-2 items-center border-stone-500 dark:border-stone-500 rounded-lg p-2"}>
        <%= for {member_info, index} <- Enum.with_index(@datainfo["members"]) do %>
          <div class="font-semibold text-gray-700 dark:text-gray-300 text-right">
            {"f#{index}"}:
          </div>
          <div>
            <.input_parameter
              datainfo={member_info}
              path={@path ++ ["f#{index}"]}
              modal_form={@modal_form}
              depth={@depth + 1}
              max_depth={@max_depth}
              parameter_id={@parameter_id}
              location={@location}
            />
          </div>
        <% end %>
      </div>
    <% end %>

    """
  end

  attr :datainfo, :map, required: true
  attr :modal_form, :map, required: true
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 1
  attr :path, :list, default: ["value"]
  attr :parameter_id, :integer, required: true
  attr :location, :string, required: true


  def input_array(assigns) do
    assigns = assigns
      |> assign(:field, Enum.join(assigns.path, "."))

    ~H"""
    <div class="flex flex-wrap items-center">

      <.input
        name={@field}
        type="text"
        field={@modal_form[@field]}
        value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
        phx-debounce="500"
        class="flex-1 max-h-80 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
      />

    </div>
    """
  end


end
