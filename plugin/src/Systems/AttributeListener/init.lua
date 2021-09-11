local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local util = require(script.Parent.util)

local createListener = require(script.createListener)

return function(system, componentName, pendingValidation, pluginMouse)
	local registry = system.registry
	local previousSelection = {}
	local dirty = true

	system
		:all(".anattaInstance", ".anattaValidationListener", componentName)
		:collect()
		:attach(createListener(registry, componentName, pendingValidation, pluginMouse))

	system:on(Selection.SelectionChanged, function()
		dirty = true
	end)

	system:on(RunService.Heartbeat, function()
		if not dirty then
			return
		end

		local currentSelection = Selection:Get()

		for _, instance in ipairs(currentSelection) do
			local isValidEntity, entity = util.tryGetValidEntityAttribute(registry, instance)

			if isValidEntity then
				previousSelection[instance] = nil
				registry:tryAdd(entity, ".anattaValidationListener")
			end
		end

		for instance in pairs(previousSelection) do
			local isValidEntity, entity = util.tryGetValidEntityAttribute(registry, instance)

			if isValidEntity then
				previousSelection[instance] = nil
				registry:tryRemove(entity, ".anattaValidationListener")
			end
		end

		for _, instance in ipairs(currentSelection) do
			previousSelection[instance] = true
		end

		dirty = false
	end)
end
