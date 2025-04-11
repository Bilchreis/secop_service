defmodule SecopService.Util do
  def display_name(name) do
    name
    |> String.split("_")
    |> Enum.map(fn x -> String.capitalize(x) end)
    |> Enum.join(" ")
  end
end
