defmodule SecopService.Sec_Nodes do
  import Ecto.Query, warn: false
  alias SecopService.Repo
  alias SecopService.Sec_Nodes.{SEC_Node, Module, Parameter, Command, ParameterValue}
  alias SecopService.Util
  require Logger
  alias Jason

  def get_recent_values(parameter, limit \\ 100) do
    schema_module = ParameterValue.get_schema_module(parameter)

    schema_module
    |> where(parameter_id: ^parameter.id)
    |> order_by(desc: :timestamp)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_values(parameter) do
    schema_module = ParameterValue.get_schema_module(parameter)

    schema_module
    |> where(parameter_id: ^parameter.id)
    |> order_by(asc: :timestamp)
    |> Repo.all()
  end

  def extract_value_timestamp_lists(parameter_values, parameter) do
    values =
      Enum.map(parameter_values, fn param_value ->
        ParameterValue.get_raw_value(param_value, parameter)
      end)

    timestamps =
      Enum.map(parameter_values, fn param_value ->
        # Extract the timestamp - using DateTime values
        DateTime.to_unix(param_value.timestamp, :millisecond)
      end)

    {values, timestamps}
  end

  def get_values_in_timerange(parameter, start_time, end_time) do
    schema_module = ParameterValue.get_schema_module(parameter)

    schema_module
    |> where(parameter_id: ^parameter.id)
    |> where([v], v.timestamp >= ^start_time)
    |> where([v], v.timestamp <= ^end_time)
    |> order_by(asc: :timestamp)
    |> Repo.all()
  end

  @doc """
  Stores SEC nodes and their components from an active_nodes map.

  Takes a map of active nodes (as returned by SEC_Node_Supervisor.get_active_nodes/0)
  and persists them to the database.

  Returns a map of {node_id => %{db_id: uuid}} for reference or errors for nodes
  that could not be stored.
  """
  def store_active_nodes(active_nodes) do
    # Process each node independently so errors with one don't affect others
    results =
      Enum.map(active_nodes, fn {node_id, node_data} ->
        case store_single_node(node_data) do
          {:ok, result} -> {node_id, result}
          {:error, reason} -> {node_id, {:error, reason}}
        end
      end)

    # Convert results to a map
    Enum.into(results, %{})
  end

  # Store a single node and its components
  def store_single_node(node_data) do
    Repo.transaction(fn ->
      # Try to create the SEC node
      case create_sec_node_from_data(node_data) do
        {:ok, db_node} ->
          # Create modules, parameters, and commands
          modules_map = store_modules_for_node(db_node, node_data)
          # Return the mapping
          %{
            db_id: db_node.uuid,
            modules: modules_map
          }

        {:error, reason} ->
          # Rollback transaction and return the error
          Repo.rollback(reason)
      end
    end)
  end

  defp check_description(describe_str, version \\ "1.0", output \\ "json") do
    result =
      try do
        {result, _globals} =
          Pythonx.eval(
            """
            from secop_check.checker import Checker

            version_str = version.decode('utf-8') if isinstance(version, bytes) else str(version)
            output_str = output.decode('utf-8') if isinstance(output, bytes) else str(output)



            checker = Checker(version_str, [], output_str)

            checker.check(descr)


            diag_list = []

            for diag in checker.get_diags():
                step = f' [{diag.step}]' if diag.step else ''
                ctx = ' / '.join(f'{ty} {name}'.strip()
                                for ty, name in diag.ctx.path).strip()
                if ctx:
                    ctx += ': '

                diag_list.append({"severity": diag.severity.name,
                "step": diag.step,
                "message": diag.msg,
                "ctx": [ list(node) for node in diag.ctx.path],
                "text":f'{diag.severity.name}{step}: {ctx}{diag.msg}'
                })

            diag_list
            """,
            %{"descr" => describe_str, "version" => version, "output" => output}
          )

        Pythonx.decode(result)
      rescue
        e in Pythonx.Error ->
          Logger.error("Python runtime error in check_description: #{inspect(e)}")

          [
            %{
              "severity" => "FATAL",
              "step" => "undefined",
              "message" => "SECoP Check Crashed",
              "ctx" => [],
              "text" => "SECoP Check Crashed"
            }
          ]
      end

    %{"version" => version, "result" => result}
  end

  # Create a SEC node from the active_nodes data
  defp create_sec_node_from_data(node_data) do
    properties = node_data.description.properties

    # Extract custom properties (keys starting with underscore)
    custom_properties =
      Enum.reduce(properties, %{}, fn {key, value}, acc ->
        if String.starts_with?(to_string(key), "_") do
          Map.put(acc, key, value)
        else
          acc
        end
      end)

    describe_str = Jason.encode!(node_data.raw_description)

    check_result = check_description(describe_str)
    # Extract basic node attributes
    attrs = %{
      uuid: node_data.uuid,
      # Fixed typo from eqipment_id
      equipment_id: node_data.equipment_id,
      host: to_string(node_data.host),
      port: node_data.port,
      description: properties.description,
      firmware: Map.get(properties, :firmware),
      implementor: Map.get(properties, :implementor),
      timeout: Map.get(properties, :timeout),
      custom_properties: custom_properties,
      describe_message: node_data.raw_description,
      describe_message_raw: describe_str,
      check_result: check_result
    }

    # Check if node with this UUID already exists
    case get_sec_node_by_uuid(attrs.uuid) do
      nil ->
        # Node doesn't exist, create it
        Logger.info("Creating SEC Node with UUID #{attrs.uuid}")
        create_sec_node(attrs)

      _existing ->
        # Node exists, return error
        Logger.warning("SEC Node with UUID #{attrs.uuid} already exists")
        {:error, "SEC Node with UUID #{attrs.uuid} already exists"}
    end
  end

  # Store modules for a node
  defp store_modules_for_node(db_node, node_data) do
    modules = get_in(node_data, [:description, :modules]) || %{}

    Enum.reduce(modules, %{}, fn {module_name, module_data}, acc ->
      # Create the module
      case create_module_from_data(db_node, module_name, module_data) do
        {:ok, db_module} ->
          # Create parameters and commands for this module
          params_map = store_parameters_for_module(db_module, module_data)
          commands_map = store_commands_for_module(db_module, module_data)

          # Return module mapping
          Map.put(acc, module_name, %{
            db_id: db_module.id,
            parameters: params_map,
            commands: commands_map
          })

        {:error, reason} ->
          Logger.error("Error storing module: #{inspect(reason)}")
          # Skip this module if creation failed
          acc
      end
    end)
  end

  # Create a module from module data
  defp create_module_from_data(db_node, module_name, module_data) do
    properties = Map.get(module_data, :properties)

    # Extract custom properties (keys starting with underscore)
    custom_properties =
      Enum.reduce(properties, %{}, fn {key, value}, acc ->
        if String.starts_with?(to_string(key), "_") do
          Map.put(acc, key, value)
        else
          acc
        end
      end)

    attrs = %{
      name: to_string(module_name),
      description: Map.get(properties, :description) || "",
      interface_classes: Map.get(properties, :interface_classes) || [],
      highest_interface_class:
        (Map.get(properties, :interface_classes) || [])
        |> Util.get_highest_if_class()
        |> Atom.to_string() || "none",
      custom_properties: custom_properties || %{},
      sec_node_id: db_node.uuid,

      ## optional properties
      visibility: Map.get(properties, :visibility) |> to_string(),
      group: Map.get(properties, :group),
      meaning: Map.get(properties, :meaning),
      implementor: Map.get(properties, :implementor)
    }

    # Only create if it doesn't exist
    case Repo.get_by(Module, sec_node_id: db_node.uuid, name: to_string(module_name)) do
      nil -> create_module(attrs)
      # Module already exists, return it
      existing -> {:ok, existing}
    end
  end

  # Store parameters for a module
  defp store_parameters_for_module(db_module, module_data) do
    parameters = Map.get(module_data, :parameters) || %{}

    Enum.reduce(parameters, %{}, fn {param_name, param_data}, acc ->
      # Create the parameter
      case create_parameter_from_data(db_module, param_name, param_data) do
        {:ok, db_param} ->
          # Return parameter mapping
          Map.put(acc, param_name, %{db_id: db_param.id})

        {:error, reason} ->
          Logger.error("Error storing parameter: #{inspect(reason)}")
          acc
      end
    end)
  end

  # Create a parameter from parameter data
  defp create_parameter_from_data(db_module, param_name, param_data) do
    properties = param_data

    # Extract custom properties (keys starting with underscore)
    custom_properties =
      Enum.reduce(properties, %{}, fn {key, value}, acc ->
        if String.starts_with?(to_string(key), "_") do
          Map.put(acc, key, value)
        else
          acc
        end
      end)

    attrs = %{
      name: to_string(param_name),
      description: Map.get(properties, :description),
      datainfo: Map.get(properties, :datainfo),
      readonly: Map.get(properties, :readonly),
      custom_properties: custom_properties,

      # optional properties
      group: Map.get(properties, :group),
      visibility: Map.get(properties, :visibility) |> to_string(),
      meaning: Map.get(properties, :meaning),
      checkable: Map.get(properties, :checkable),
      module_id: db_module.id
    }

    # Only create if it doesn't exist
    case Repo.get_by(Parameter, module_id: db_module.id, name: to_string(param_name)) do
      nil ->
        create_parameter(attrs)

      # Parameter already exists, return it
      existing ->
        {:ok, existing}
    end
  end

  # Store commands for a module
  defp store_commands_for_module(db_module, module_data) do
    commands = Map.get(module_data, :commands) || %{}

    Enum.reduce(commands, %{}, fn {cmd_name, cmd_data}, acc ->
      # Create the command

      case create_command_from_data(db_module, cmd_name, cmd_data) do
        {:ok, db_cmd} ->
          # Return command mapping
          Map.put(acc, cmd_name, %{db_id: db_cmd.id})

        {:error, reason} ->
          Logger.error("Error storing command: #{inspect(reason)}")
          # Skip this command if creation failed
          acc
      end
    end)
  end

  # Create a command from command data
  defp create_command_from_data(db_module, cmd_name, cmd_data) do
    properties = cmd_data

    # Extract custom properties (keys starting with underscore)
    custom_properties =
      Enum.reduce(properties, %{}, fn {key, value}, acc ->
        if String.starts_with?(to_string(key), "_") do
          Map.put(acc, key, value)
        else
          acc
        end
      end)

    attrs = %{
      name: to_string(cmd_name),
      description: Map.get(properties, :description),
      datainfo: Map.get(properties, :datainfo),
      custom_properties: custom_properties,
      module_id: db_module.id,
      argument: Map.get(properties, :datainfo) |> Map.get(:argument),
      result: Map.get(properties, :datainfo) |> Map.get(:result),

      # optional properties
      group: Map.get(properties, :group),
      visibility: Map.get(properties, :visibility) |> to_string(),
      meaning: Map.get(properties, :meaning),
      checkable: Map.get(properties, :checkable)
    }

    # Only create if it doesn't exist
    case Repo.get_by(Command, module_id: db_module.id, name: to_string(cmd_name)) do
      nil -> create_command(attrs)
      # Command already exists, return it
      existing -> {:ok, existing}
    end
  end

  # Basic CRUD functions with no updates

  # Create a new SEC node
  @doc """
  Creates a new SEC node with the provided attributes.

  ## Parameters

    * `attrs` - Map containing node attributes:
      * `:equipment_id` - Unique identifier for the equipment (required)
      * `:uuid` - Unique identifier for the node (required)
      * `:host` - Hostname or IP address (required)
      * `:port` - Port number (required)
      * `:description` - Optional description
      * `:properties` - Map of additional properties
      * `:describe_message` - Full SECoP describe message

  ## Returns

    * `{:ok, sec_node}` - Returns the created node on success
    * `{:error, changeset}` - Returns the changeset with errors on failure
    * `{:error, string}` - Returns error message if node already exists
  """
  def create_sec_node(attrs) do
    %SEC_Node{}
    |> SEC_Node.changeset(attrs)
    |> Repo.insert()
  end

  def create_module(attrs) do
    %Module{}
    |> Module.changeset(attrs)
    |> Repo.insert()
  end

  def create_parameter(attrs) do
    %Parameter{}
    |> Parameter.changeset(attrs)
    |> Repo.insert()
  end

  def create_command(attrs) do
    %Command{}
    |> Command.changeset(attrs)
    |> Repo.insert()
  end

  def get_sec_node_by_uuid(uuid) do
    SEC_Node
    |> Repo.get_by(uuid: uuid)
    |> Repo.preload(
      modules: {
        from(m in Module, order_by: m.name),
        [
          parameters: from(p in Parameter, order_by: p.name),
          commands: from(c in Command, order_by: c.name)
        ]
      }
    )
  end

  # Query functions
  def list_sec_nodes(params \\ %{}) do
    Flop.validate_and_run(
      SEC_Node,
      params,
      for: SEC_Node,
      # Defaults to 25 if not provided
      default_limit: 10,
      # Prevents going above 100
      max_limit: 30
    )
  end

  def list_parameter_values(parameter, params \\ %{}) do
    schema_module = ParameterValue.get_schema_module(parameter)

    query = from(pv in schema_module, where: pv.parameter_id == ^parameter.id)

    Flop.validate_and_run(
      query,
      params,
      for: schema_module,
      default_limit: 15,
      max_limit: 100,
      default_order: %{order_by: [:timestamp], order_directions: [:desc]}
    )
  end

  def get_module(id), do: Repo.get(Module, id)

  def get_parameter(id), do: Repo.get(Parameter, id)

  def get_command(id), do: Repo.get(Command, id)

  def get_node(id), do: Repo.get(SEC_Node, id)

  @doc """
  Checks if a SEC node with the given UUID exists in the database.

  ## Parameters

    * `uuid` - The UUID to check

  ## Returns

    * `true` - A node with this UUID exists
    * `false` - No node with this UUID exists
  """
  def node_exists?(uuid) when is_binary(uuid) do
    query = from n in SEC_Node, where: n.uuid == ^uuid, select: 1, limit: 1
    Repo.exists?(query)
  end

  # Handle nil case
  def node_exists?(nil), do: false
end
