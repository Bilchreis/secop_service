defmodule SecopServiceWeb.NodeControl do
  require Logger
  alias SEC_Node_Statem
  alias Jason
  alias SecopServiceWeb.DashboardLive.Model, as: Model

  def change(set_form, model) do
    nodeid = {String.to_charlist(set_form["host"]), String.to_integer(set_form["port"])}

    module = set_form["module"]
    parameter = set_form["parameter"]
    value = set_form["value"]

    return = SEC_Node_Statem.change(nodeid, module, parameter, value)
  end

  def validate(set_form, model) do
    nodeid = {String.to_charlist(set_form["host"]), String.to_integer(set_form["port"])}

    module = String.to_atom(set_form["module"])
    parameter = String.to_atom(set_form["parameter"])

    parameter_map = Model.get_parameter(model, nodeid, module, parameter)

    datainfo = parameter_map.datainfo

    parameter_map =
      case Jason.decode(set_form["value"], keys: :atoms) do
        {:ok, value} ->
          case validate_against_datainfo(datainfo, value) do
            {:ok, _} ->
              # Add validation indicator AND update the form's value
              set_form = %{
                parameter_map.set_form
                | params: Map.put(parameter_map.set_form.params, "value", set_form["value"]),
                  source: Map.put(parameter_map.set_form.source, "value", set_form["value"]),
                  errors: []
              }

              parameter_map
              |> Map.put(:validation, "border-4 border-green-500")
              |> Map.put(:set_form, set_form)

            {:error, msg} ->
              set_form = parameter_map.set_form

              # Field-specific error
              set_form = %{parameter_map.set_form | errors: [value: {msg, []}]}
              Map.put(parameter_map, :set_form, set_form)
          end

        {:error, _} ->
          # Field-specific JSON error
          set_form = %{parameter_map.set_form | errors: [value: {"Invalid JSON format", []}]}
          Map.put(parameter_map, :set_form, set_form)
      end

    Model.set_parameter(model, nodeid, module, parameter, parameter_map)
  end

  def validate_against_datainfo(datainfo, value) do
    case datainfo.type do
      "double" -> validate_double(datainfo, value)
      "int" -> validate_int(datainfo, value)
      "scaled" -> validate_scaled(datainfo, value)
      "bool" -> validate_bool(datainfo, value)
      "enum" -> validate_enum(datainfo, value)
      "string" -> validate_string(datainfo, value)
      "blob" -> validate_blob(datainfo, value)
      "array" -> validate_array(datainfo, value)
      "tuple" -> validate_tuple(datainfo, value)
      "struct" -> validate_struct(datainfo, value)
      "matrix" -> validate_matrix(datainfo, value)
      _ -> {:error, "Unknown data type"}
    end
  end

  def validate_double(datainfo, value) do
    cond do
      not is_number(value) ->
        {:error, "Value must be a number"}

      Map.has_key?(datainfo, :min) and value < datainfo.min ->
        {:error, "Value #{value} is below minimum #{datainfo.min}"}

      Map.has_key?(datainfo, :max) and value > datainfo.max ->
        {:error, "Value #{value} is above maximum #{datainfo.max}"}

      true ->
        {:ok, value}
    end
  end

  def validate_int(datainfo, value) do
    cond do
      not is_integer(value) ->
        {:error, "Value must be an integer"}

      Map.has_key?(datainfo, :min) and value < datainfo.min ->
        {:error, "Value #{value} is below minimum #{datainfo.min}"}

      Map.has_key?(datainfo, :max) and value > datainfo.max ->
        {:error, "Value #{value} is above maximum #{datainfo.max}"}

      true ->
        {:ok, value}
    end
  end

  def validate_scaled(datainfo, value) do
    validate_int(datainfo, value)
  end

  def validate_bool(_datainfo, value) do
    if is_boolean(value) do
      {:ok, value}
    else
      {:error, "Value must be true or false"}
    end
  end

  def validate_enum(datainfo, value) do
    if not is_integer(value) do
      {:error, "Enum value must be an integer"}
    else
      # Check if value is in the members values
      if Map.values(datainfo.members) |> Enum.member?(value) do
        {:ok, value}
      else
        valid_values = Map.values(datainfo.members) |> Enum.join(", ")
        {:error, "Invalid enum value. Must be one of: #{valid_values}"}
      end
    end
  end

  def validate_string(datainfo, value) do
    cond do
      not is_binary(value) ->
        {:error, "Value must be a string"}

      Map.has_key?(datainfo, :maxchars) and String.length(value) > datainfo.maxchars ->
        {:error, "String exceeds maximum length of #{datainfo.maxchars} characters"}

      Map.has_key?(datainfo, :minchars) and String.length(value) < datainfo.minchars ->
        {:error, "String is shorter than minimum length of #{datainfo.minchars} characters"}

      Map.get(datainfo, :isUTF8, false) == false and
          String.to_charlist(value) |> Enum.any?(fn c -> c > 127 end) ->
        {:error, "String contains non-ASCII characters"}

      true ->
        {:ok, value}
    end
  end

  def validate_blob(datainfo, value) do
    try do
      decoded = Base.decode64!(value)
      size = byte_size(decoded)

      cond do
        Map.has_key?(datainfo, :maxbytes) and size > datainfo.maxbytes ->
          {:error, "Blob exceeds maximum size of #{datainfo.maxbytes} bytes"}

        Map.has_key?(datainfo, :minbytes) and size < datainfo.minbytes ->
          {:error, "Blob is smaller than minimum size of #{datainfo.minbytes} bytes"}

        true ->
          {:ok, value}
      end
    rescue
      _ -> {:error, "Invalid base64 encoded string"}
    end
  end

  def validate_array(datainfo, value) do
    if not is_list(value) do
      {:error, "Value must be an array"}
    else
      size = length(value)

      cond do
        Map.has_key?(datainfo, :maxlen) and size > datainfo.maxlen ->
          {:error, "Array exceeds maximum length of #{datainfo.maxlen} items"}

        Map.has_key?(datainfo, :minlen) and size < datainfo.minlen ->
          {:error, "Array is shorter than minimum length of #{datainfo.minlen} items"}

        true ->
          # Validate each element against the member type
          results = Enum.map(value, &validate_against_datainfo(datainfo.members, &1))
          errors = Enum.filter(results, fn {status, _} -> status == :error end)

          if Enum.empty?(errors) do
            {:ok, value}
          else
            # Return first error
            hd(errors)
          end
      end
    end
  end

  def validate_tuple(datainfo, value) do
    if not is_list(value) do
      {:error, "Value must be a tuple (JSON array)"}
    else
      value_size = length(value)
      expected_size = length(datainfo.members)

      if value_size != expected_size do
        {:error, "Tuple must have exactly #{expected_size} elements, got #{value_size}"}
      else
        # Validate each element against corresponding member type
        results =
          Enum.zip(value, datainfo.members)
          |> Enum.map(fn {val, type} -> validate_against_datainfo(type, val) end)

        errors = Enum.filter(results, fn {status, _} -> status == :error end)

        if Enum.empty?(errors) do
          {:ok, value}
        else
          # Return first error
          hd(errors)
        end
      end
    end
  end

  def validate_struct(datainfo, value) do
    if not is_map(value) do
      {:error, "Value must be a struct (JSON object)"}
    else
      # Get required member keys (all members except optional ones)
      optional_members = Map.get(datainfo, :optional, [])
      required_keys = Map.keys(datainfo.members) -- optional_members

      # Check if all required keys are present
      missing_keys = Enum.filter(required_keys, fn key -> not Map.has_key?(value, key) end)

      if not Enum.empty?(missing_keys) do
        {:error, "Missing required fields: #{Enum.join(missing_keys, ", ")}"}
      else
        # Validate each present field against its type definition
        results =
          for {k, v} <- value, Map.has_key?(datainfo.members, k) do
            member_type = datainfo.members[k]
            {k, validate_against_datainfo(member_type, v)}
          end

        errors = Enum.filter(results, fn {_, {status, _}} -> status == :error end)

        if Enum.empty?(errors) do
          {:ok, value}
        else
          # Return first error with field name
          {field, {_, msg}} = hd(errors)
          {:error, "Field '#{field}': #{msg}"}
        end
      end
    end
  end

  def validate_matrix(datainfo, value) do
    # Matrix is transmitted as a JSON object with "len" and "blob" fields
    if not is_map(value) do
      {:error, "Matrix must be a JSON object"}
    else
      if not (Map.has_key?(value, "len") and Map.has_key?(value, "blob")) do
        {:error, "Matrix must have 'len' and 'blob' fields"}
      else
        len = value["len"]
        blob = value["blob"]

        # Validate dimensions
        if not is_list(len) do
          {:error, "Matrix 'len' field must be an array"}
        else
          expected_dimensions = length(datainfo.names)
          actual_dimensions = length(len)

          if expected_dimensions != actual_dimensions do
            {:error,
             "Matrix has wrong number of dimensions (expected #{expected_dimensions}, got #{actual_dimensions})"}
          else
            # Check dimension lengths against maxlen
            dim_errors =
              Enum.zip(len, datainfo.maxlen)
              |> Enum.filter(fn {actual, max} -> actual > max end)

            if not Enum.empty?(dim_errors) do
              {actual, max} = hd(dim_errors)
              {:error, "Matrix dimension exceeds maximum length (#{actual} > #{max})"}
            else
              try do
                # Try to decode the blob (just for validation)
                _decoded = Base.decode64!(blob)
                {:ok, value}
              rescue
                _ -> {:error, "Invalid base64 encoded matrix data"}
              end
            end
          end
        end
      end
    end
  end
end
