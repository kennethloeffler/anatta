local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Constants = require(script.Parent.Parent.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

return function(system, registry, componentName, pendingValidation)
	local previousSelection = {}
	local dirty = true

	system
		:all("__anattaPluginInstance", "__anattaPluginValidationListener")
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
							registry:destroy(entity)
						elseif currentValue ~= entity then
							registry:tryAdd(entity, "__anattaPluginForceEntityAttribute")
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
			local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

			if entity == nil or not registry:valid(entity) then
				continue
			end

			previousSelection[instance] = nil
			registry:tryAdd(entity, "__anattaPluginValidationListener")
		end

		for instance in pairs(previousSelection) do
			local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

			if entity == nil or not registry:valid(entity) then
				continue
			end

			previousSelection[instance] = nil
			registry:tryRemove(entity, "__anattaPluginValidationListener")
		end

		for _, instance in ipairs(currentSelection) do
			previousSelection[instance] = true
		end

		dirty = false
	end)
end
