local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Constants = require(script.Parent.Parent.Constants)
local util = require(script.Parent.util)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

return function(system, registry)
	local previousSelection = {}
	local dirty = false
	local entitiesToListenTo = system
		:all("__anattaInstance", "__anattaValidationListener")
		:collect()

	entitiesToListenTo:attach(function(entity, instance)
		return {
			instance.AttributeChanged:Connect(function(attributeName)
				local currentValue = instance:GetAttribute(attributeName)

				if attributeName == ENTITY_ATTRIBUTE_NAME then
					if currentValue ~= entity then
						registry:tryAdd(entity, "__anattaForceEntityAttribute")
					end
				elseif currentValue == nil then
					registry:tryRemove(entity, "__anattaPendingValidation")
					return
				else
					registry:visit(function(componentName)
						if attributeName:find(componentName) then
							registry:tryAdd(entity, "__anattaPendingValidation")
							return true
						end
					end, entity)
				end
			end),
		}
	end)

	system:on(Selection.SelectionChanged, function()
		dirty = true
	end)

	system:on(RunService.Heartbeat, function()
		if not dirty then
			return
		end

		local currentSelection = Selection:Get()

		for _, instance in ipairs(currentSelection) do
			if instance:GetAttribute(ENTITY_ATTRIBUTE_NAME) == nil then
				continue
			end

			previousSelection[instance] = nil
			registry:tryAdd(util.getValidEntity(registry, instance), "__anattaValidationListener")
		end

		for instance in pairs(previousSelection) do
			if instance:GetAttribute(ENTITY_ATTRIBUTE_NAME) == nil then
				continue
			end

			registry:tryRemove(util.getValidEntity(registry, instance), "__anattaValidationListener")
			previousSelection[instance] = nil
		end

		for _, instance in ipairs(currentSelection) do
			previousSelection[instance] = true
		end

		dirty = false
	end)
end
