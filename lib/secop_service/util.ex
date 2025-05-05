defmodule SecopService.Util do
  def display_name(name) do
    name
    |> String.split("_")
    |> Enum.map(fn x -> String.capitalize(x) end)
    |> Enum.join(" ")
  end

  def get_highest_if_class(iflist) do
    cond do
      Enum.member?(iflist, "Triggerable") -> :measurable
      Enum.member?(iflist, "Measurable") -> :measurable
      Enum.member?(iflist, "Drivable") -> :drivable
      Enum.member?(iflist, "Readable") -> :readable
      Enum.member?(iflist, "Communicator") -> :communicator
      true -> nil
    end
  end
end
