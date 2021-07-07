local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Constants = require(script.Parent.Parent.Constants)
local util = require(script.Parent.util)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local PENDING_VALIDATION = Constants.PendingValidation

return function(system, registry)
	local previousSelection = {}
	local dirty = false
	local entitiesToListenTo = system
		:all("__anattaPluginInstance", "__anattaPluginValidationListener")
		:collect()

	entitiesToListenTo:attach(function(entity, instance)
		return {
			instance.AttributeChanged:Connect(function(attributeName)
				if not registry:valid(entity) then
					return
				end

				local currentValue = instance:GetAttribute(attributeName)

				if attributeName == ENTITY_ATTRIBUTE_NAME then
					if currentValue == nil then
						registry:destroy(entity)
					elseif currentValue ~= entity then
						registry:tryAdd(entity, "__anattaPluginForceEntityAttribute")
					end
				elseif currentValue ~= nil then
					registry:visit(function(componentName)
						if attributeName:find(componentName) then
							registry:tryAdd(entity, PENDING_VALIDATION:format(componentName))
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
			registry:tryAdd(
				util.getValidEntity(registry, instance),
				"__anattaPluginValidationListener"
			)
		end

		for instance in pairs(previousSelection) do
			if instance:GetAttribute(ENTITY_ATTRIBUTE_NAME) == nil then
				continue
			end

			registry:tryRemove(
				util.getValidEntity(registry, instance),
				"__anattaPluginValidationListener"
			)
			previousSelection[instance] = nil
		end

		for _, instance in ipairs(currentSelection) do
			previousSelection[instance] = true
		end

		dirty = false
	end)
end
