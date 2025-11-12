alias SecopService.PlotDB
alias SecopService.Sec_Nodes
alias Ecto.UUID

abstract_modules =
  Sec_Nodes.get_sec_node_by_uuid(UUID.dump!("aa134b51-c8ae-4b5a-93d0-49e4356d4d7c"))
  |> Map.get(:modules)

gas_dosing_modules =
  Sec_Nodes.get_sec_node_by_uuid(UUID.dump!("62245730-72b4-4fd5-8929-8a8c69e3f48e"))
  |> Map.get(:modules)

gas_op_mode = Enum.find(abstract_modules, fn m -> m.name == "gas_operation_mode" end)
mfc_group1 = Enum.find(abstract_modules, fn m -> m.name == "MFC_group_1" end)
mfc1 = Enum.find(gas_dosing_modules, fn m -> m.name == "massflow_contr1" end)

Benchee.run(%{
  "gas_op_mode" => fn -> PlotDB.drivable_plot(gas_op_mode) end,
  "mfc_group1" => fn -> PlotDB.drivable_plot(mfc_group1) end,
  "mfc1" => fn -> PlotDB.drivable_plot(mfc1) end
})

:eprof.start_profiling([self()])

PlotDB.drivable_plot(gas_op_mode)

:eprof.stop_profiling()
:eprof.analyze()
