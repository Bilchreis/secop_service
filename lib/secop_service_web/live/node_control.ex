defmodule SecopServiceWeb.NodeControl do
  alias SEC_Node_Statem


  def change(set_form) do
    nodeid  = {String.to_charlist(set_form["host"]),String.to_integer(set_form["port"])}

    module = set_form["module"]
    parameter = set_form["parameter"]
    value = set_form["value"]

    return = SEC_Node_Statem.change(nodeid, module, parameter, value)

    IO.inspect(return)
  end

end
