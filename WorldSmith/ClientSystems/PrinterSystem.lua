function PrinterSystem(EntityManager)
	
	local function setupPrinter(printer)
		EntityManager:GetComponentAddedSignal("_trigger", printer.Parent):connect(function(triggerEvent)
			EntityManager:KillComponent(printer.Parent, "_trigger")
			print(printer.MsgToPrint)
		end)
	end
	
	local printers = EntityManager:GetAllComponentsOfType("PrintToOutput")
	for _, printer in pairs(printers) do
		setupPrinter(printer)
	end
	
	EntityManager:GetComponentAddedSignal("PrintToOutput"):connect(function(entity)
		local printer = EntityManager:GetComponent(entity, "PrintToOutput")
		setupPrinter(printer)
	end)
end

return PrinterSystem
