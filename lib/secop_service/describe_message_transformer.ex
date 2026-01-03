defmodule SecopService.DescribeMessageTransformer do
  @moduledoc """
  Transforms SEC_Node_Statem state into database-ready format for Ash resources.
  Pure transformation logic with no database interaction.
  """

  @doc """
  Transforms a SEC_Node_Statem state into the format expected by SecNode Ash resource.

  ## Parameters
  - `statem_state` - The state map from SEC_Node_Statem containing:
    - `:host` - Host address
    - `:port` - Port number
    - `:equipment_id` - Equipment identifier
    - `:description` - Parsed description map
    - `:raw_description` - Raw JSON description string
    - `:uuid` - Optional UUID (will be generated if not provided)
    - Other metadata fields

  ## Returns
  Map ready for Ash.Changeset.for_create/2
  """
  def transform(statem_state) do
    description = statem_state[:description] || %{}
    properties = description[:properties] || %{}

    %{
      uuid: statem_state[:uuid] || Ash.UUID.generate(),
      equipment_id: statem_state[:equipment_id] || properties[:equipment_id],
      host: to_string(statem_state[:host]),
      port: statem_state[:port],
      description: properties[:description],
      firmware: properties[:firmware],
      implementor: properties[:implementor],
      timeout: properties[:timeout],
      describe_message: description,
      describe_message_raw: statem_state[:raw_description],
      custom_properties: extract_custom_properties(properties),
      modules: transform_modules(description[:modules] || %{})
    }
  end

  defp transform_modules(modules_map) when is_map(modules_map) do
    Enum.map(modules_map, fn {module_name, module_data} ->
      accessibles = module_data[:accessibles] || %{}

      %{
        name: to_string(module_name),
        description: module_data[:description],
        interface_classes: module_data[:interface_classes] || [],
        highest_interface_class: List.first(module_data[:interface_classes] || []),
        visibility: module_data[:visibility],
        group: module_data[:group],
        meaning: module_data[:meaning],
        implementor: module_data[:implementation],
        custom_properties: extract_module_custom_properties(module_data),
        parameters: transform_parameters(accessibles),
        commands: transform_commands(accessibles)
      }
    end)
  end

  defp transform_parameters(accessibles) when is_map(accessibles) do
    accessibles
    |> Enum.filter(fn {_name, data} ->
      get_in(data, [:datainfo, :type]) != "command"
    end)
    |> Enum.map(fn {param_name, param_data} ->
      %{
        name: to_string(param_name),
        datainfo: param_data[:datainfo],
        readonly: param_data[:readonly],
        description: param_data[:description],
        group: param_data[:group],
        visibility: param_data[:visibility],
        meaning: param_data[:meaning],
        checkable: param_data[:checkable],
        custom_properties: extract_accessible_custom_properties(param_data)
      }
    end)
  end

  defp transform_commands(accessibles) when is_map(accessibles) do
    accessibles
    |> Enum.filter(fn {_name, data} ->
      get_in(data, [:datainfo, :type]) == "command"
    end)
    |> Enum.map(fn {cmd_name, cmd_data} ->
      datainfo = cmd_data[:datainfo] || %{}

      %{
        name: to_string(cmd_name),
        description: cmd_data[:description],
        datainfo: datainfo,
        argument: datainfo[:argument],
        result: datainfo[:result],
        group: cmd_data[:group],
        visibility: cmd_data[:visibility],
        meaning: cmd_data[:meaning],
        checkable: cmd_data[:checkable],
        custom_properties: extract_accessible_custom_properties(cmd_data)
      }
    end)
  end

  # Extract custom properties (fields not part of standard SECoP spec)
  defp extract_custom_properties(properties) when is_map(properties) do
    standard_keys = [:description, :equipment_id, :firmware, :implementor, :timeout]

    properties
    |> Map.drop(standard_keys)
    |> case do
      empty when map_size(empty) == 0 -> nil
      custom -> custom
    end
  end

  defp extract_module_custom_properties(module_data) when is_map(module_data) do
    standard_keys = [:accessibles, :description, :features, :group,
                     :implementation, :interface_classes, :visibility, :meaning]

    module_data
    |> Map.drop(standard_keys)
    |> case do
      empty when map_size(empty) == 0 -> nil
      custom -> custom
    end
  end

  defp extract_accessible_custom_properties(accessible_data) when is_map(accessible_data) do
    standard_keys = [:datainfo, :description, :readonly, :group,
                     :visibility, :meaning, :checkable]

    accessible_data
    |> Map.drop(standard_keys)
    |> case do
      empty when map_size(empty) == 0 -> nil
      custom -> custom
    end
  end
end
