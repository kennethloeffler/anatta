local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)
local Constants = require(script.Parent.Parent.Constants)
local util = require(script.Parent.util)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

return function(system, registry, componentName, pendingValidation, pluginMouse)
	local typeDefinition = registry:getDefinition(componentName)
	local previousSelection = {}
	local dirty = true

	system
		:all(".anattaInstance", ".anattaValidationListener", componentName)
		:collect()
		:attach(function(entity, instance)
			return {
				instance.AttributeChanged:Connect(function(attributeName)
					if not registry:valid(entity) then
						return
					end

					local currentValue = instance:GetAttribute(attributeName)
					local _, attributeMap = Anatta.Dom.tryToAttribute(
						instance,
						registry:get(entity, componentName),
						componentName,
						typeDefinition
					)

					if attributeName == ENTITY_ATTRIBUTE_NAME then
						if currentValue == nil then
							registry:tryAdd(entity, ".anattaScheduledDestruction", tick())
						elseif currentValue ~= entity then
							registry:tryAdd(entity, ".anattaForceEntityAttribute")
						end
					elseif attributeMap[attributeName] ~= nil then
						if typeof(attributeMap[attributeName]) ~= "Instance" then
							registry:tryAdd(entity, pendingValidation)
						elseif currentValue == nil then
							local originalSelection = Selection:Get()

							Selection:Set({})

							-- This doesn't work for some reason x_x
							pluginMouse.Icon = "rbxassetid://7087918593"
							Selection.SelectionChanged:Wait()

							local ref = Selection:Get()[1]

							instance.__anattaRefs[attributeName].Value = ref
							pluginMouse.Icon = ""
							registry:tryAdd(entity, pendingValidation)
							instance:SetAttribute(attributeName, ref:GetFullName())

							-- This yield is required to set the selection back to what it was.
							RunService.Heartbeat:Wait()
							Selection:Set(originalSelection)
						else
							instance:SetAttribute(
								attributeName,
								instance.__anattaRefs[attributeName].Value:GetFullName()
							)
						end
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
