local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Constants = require(script.Parent.Parent.Constants)
local util = require(script.Parent.util)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

return function(system, registry, componentName, pendingValidation)
	local previousSelection = {}
	local dirty = true

	system
		:all(".anattaInstance", ".anattaValidationListener")
		:collect()
		:attach(function(entity, instance)
			return {
				instance.AttributeChanged:Connect(function(attributeName)
					if not registry:valid(entity) then
						return
					end

					local currentValue = instance:GetAttribute(attributeName)

					if attributeName == ENTITY_ATTRIBUTE_NAME then
						if currentValue == nil then
							registry:tryAdd(entity, ".anattaScheduledDestruction", tick())
						elseif currentValue ~= entity then
							registry:tryAdd(entity, ".anattaForceEntityAttribute")
						end
					elseif attributeName:find(componentName) then
						registry:tryAdd(entity, pendingValidation)
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
