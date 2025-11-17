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
        <.input_struct
          datainfo={@datainfo}
          location={@location}
          modal_form={@modal_form}
          depth={@depth}
          max_depth={@max_depth}
          path={@path}
          parameter_id={@parameter_id}
        />
      <% "tuple" -> %>
        <.input_tuple
          datainfo={@datainfo}
          location={@location}
          modal_form={@modal_form}
          depth={@depth}
          max_depth={@max_depth}
          path={@path}
          parameter_id={@parameter_id}
        />
      <% type when type in ["double", "int", "scaled"] -> %>
        <.input_numeric
          datainfo={@datainfo}
          location={@location}
          modal_form={@modal_form}
          depth={@depth}
          max_depth={@max_depth}
          path={@path}
          parameter_id={@parameter_id}
        />
      <% "bool" -> %>
        <.input_bool
          datainfo={@datainfo}
          location={@location}
          modal_form={@modal_form}
          depth={@depth}
          max_depth={@max_depth}
          path={@path}
          parameter_id={@parameter_id}
        />
      <% "enum" -> %>
        <.input_enum
          datainfo={@datainfo}
          location={@location}
          modal_form={@modal_form}
          depth={@depth}
          max_depth={@max_depth}
          path={@path}
          parameter_id={@parameter_id}
        />
      <% "array" -> %>
        <.input_array
          datainfo={@datainfo}
          location={@location}
          modal_form={@modal_form}
          depth={@depth}
          max_depth={@max_depth}
          path={@path}
          parameter_id={@parameter_id}
        />
      <% "string" -> %>
        <.input_string
          datainfo={@datainfo}
          location={@location}
          modal_form={@modal_form}
          depth={@depth}
          max_depth={@max_depth}
          path={@path}
          parameter_id={@parameter_id}
        />
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
    assigns =
      assigns
      |> assign(:field, Enum.join(assigns.path, "."))
      |> assign(
        :popover_id,
        "popover-" <>
          assigns.location <> "-" <> assigns.parameter_id <> Enum.join(assigns.path, "-")
      )

    ~H"""
    <.input
      name={@field}
      type="number"
      field={@modal_form[@field]}
      value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
      phx-debounce="500"
      class="flex-1 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 font-mono text-gray-900 dark:text-gray-200 opacity-100"
    />

    <.datainfo_tooltip popover_id={@popover_id} datainfo={@datainfo} />
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
    assigns =
      assigns
      |> assign(:field, Enum.join(assigns.path, "."))
      |> assign(
        :popover_id,
        "popover-" <>
          assigns.location <> "-" <> assigns.parameter_id <> Enum.join(assigns.path, "-")
      )

    ~H"""
    <.input
      name={@field}
      type="text"
      field={@modal_form[@field]}
      value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
      phx-debounce="500"
      class="flex-1 full-w max-h-80 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
    />
    <.datainfo_tooltip popover_id={@popover_id} datainfo={@datainfo} />
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
    assigns =
      assigns
      |> assign(:field, Enum.join(assigns.path, "."))
      |> assign(
        :popover_id,
        "popover-" <>
          assigns.location <> "-" <> assigns.parameter_id <> Enum.join(assigns.path, "-")
      )

    ~H"""
    <.input
      name={@field}
      type="checkbox"
      field={@modal_form[@field]}
      value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
      phx-debounce="500"
      class="bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
    />
    <.datainfo_tooltip popover_id={@popover_id} datainfo={@datainfo} />
    """
  end

  attr :datainfo, :map, required: true
  attr :modal_form, :map, required: true
  attr :depth, :integer, default: 0
  attr :max_depth, :integer, default: 1
  attr :path, :list, default: ["value"]
  attr :parameter_id, :string, required: true
  attr :location, :string, required: true
  attr :show_tooltip, :boolean, default: true
  attr :id, :string, default: nil
  attr :class, :string, default: ""

  def input_enum(assigns) do
    select_options = assigns.datainfo["members"]

    base_class =
      "flex-1 full-w bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 font-mono text-gray-900 dark:text-gray-200 opacity-100"

    class = if assigns[:class], do: "#{base_class} #{assigns[:class]}", else: base_class

    assigns =
      assigns
      |> assign(:field, Enum.join(assigns.path, "."))
      |> assign(:options, select_options)
      |> assign(
        :popover_id,
        "popover-" <>
          assigns.location <>
          "-" <> to_string(assigns.parameter_id) <> Enum.join(assigns.path, "-")
      )
      |> assign(:class, class)

    ~H"""
    <.input
      id={@id}
      name={@field}
      type="select"
      options={@options}
      field={@modal_form[@field]}
      value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
      phx-debounce="500"
      class={@class}
    />
    <%= if @show_tooltip do %>
      <.datainfo_tooltip popover_id={@popover_id} datainfo={@datainfo} />
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

  def input_struct(assigns) do
    assigns =
      assigns
      |> assign(:field, Enum.join(assigns.path, "."))
      |> assign(
        :grid_cols,
        if(length(Map.to_list(assigns.datainfo["members"])) > 6,
          do: "grid-cols-3",
          else: "grid-cols-1"
        )
      )
      |> assign(
        :popover_id,
        "popover-" <>
          assigns.location <> "-" <> assigns.parameter_id <> Enum.join(assigns.path, "-")
      )

    ~H"""
    Struct:
    <%= if @depth >= @max_depth do %>
      <.input
        name={@field}
        type="text"
        field={@modal_form[@field]}
        value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
        phx-debounce="500"
        class="flex-1 full-w max-h-80 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
      />
      <.datainfo_tooltip popover_id={@popover_id} datainfo={@datainfo} />
    <% else %>
      <div class={"grid #{@grid_cols} gap-x-2 gap-y-2 items-center border-stone-500 dark:border-stone-500 rounded-lg  border p-2"}>
        <%= for {member_name, member_info} <- @datainfo["members"] do %>
          <div class="grid grid-cols-2 gap-2 items-center w-full">
            <div class="font-semibold text-gray-700 dark:text-gray-300 text-right">
              {member_name}:
            </div>
            <div class="flex items-center gap-2">
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
    assigns =
      assigns
      |> assign(:field, Enum.join(assigns.path, "."))
      |> assign(
        :grid_cols,
        if(length(assigns.datainfo["members"]) > 6, do: "grid-cols-3", else: "grid-cols-1")
      )
      |> assign(
        :popover_id,
        "popover-" <>
          assigns.location <> "-" <> assigns.parameter_id <> Enum.join(assigns.path, "-")
      )

    ~H"""
    Tuple:
    <%= if @depth >= @max_depth do %>
      <.input
        name={@field}
        type="text"
        field={@modal_form[@field]}
        value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
        phx-debounce="500"
        class="flex-1 full-w max-h-80 bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 overflow-scroll font-mono text-gray-900 dark:text-gray-200 opacity-100"
      />
      <.datainfo_tooltip popover_id={@popover_id} datainfo={@datainfo} />
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
    assigns =
      assigns
      |> assign(:field, Enum.join(assigns.path, "."))
      |> assign(
        :popover_id,
        "popover-" <>
          assigns.location <> "-" <> assigns.parameter_id <> Enum.join(assigns.path, "-")
      )

    ~H"""
    <.input
      name={@field}
      type="text"
      field={@modal_form[@field]}
      value={Phoenix.HTML.Form.input_value(@modal_form, @field)}
      phx-debounce="500"
      class="w-full bg-zinc-300 dark:bg-zinc-600 border rounded-lg p-2  border-stone-500 dark:border-stone-500 font-mono text-gray-900 dark:text-gray-200 opacity-100"
    />

    <.datainfo_tooltip popover_id={@popover_id} datainfo={@datainfo} />
    """
  end

  attr :popover_id, :string, required: true
  attr :datainfo, :string, required: true

  def datainfo_tooltip(assigns) do
    assigns =
      assigns
      |> assign(:pretty_datainfo, Jason.encode!(assigns.datainfo, pretty: true))

    ~H"""
    <div class="flex-none with-tooltip" aria-describedby={@popover_id}>
      <.icon name="hero-information-circle" class=" h-6 w-6  mr-1" />

      <div
        role="tooltip"
        id={@popover_id}
        class="absolute z-[20] px-3 py-2 bg-gray-100 dark:bg-gray-600 border  rounded-lg border-stone-500 dark:border-stone-500 "
      >
        <span class="text-gray-800 dark:text-gray-200">Datainfo:</span>
        <pre class="break-words max-h-[60vh] overflow-y-auto bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200 font-mono text-xs p-2 rounded-lg">{@pretty_datainfo}</pre>
      </div>
    </div>
    """
  end
end
