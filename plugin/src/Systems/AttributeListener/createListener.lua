local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)
local Constants = require(script.Parent.Parent.Parent.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

return function(registry, componentName, pendingValidation, pluginMouse)
	local typeDefinition = registry:getDefinition(componentName)

	return function(entity, instance)
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
					if typeof(attributeMap[attributeName]) == "Instance" then
						if currentValue ~= nil then
							local ref = instance.__anattaRefs[attributeName].Value

							instance:SetAttribute(
								attributeName,
								ref.Parent ~= nil and ref.Name or ""
							)

							Selection:Set({ ref })
							return
						end

						local originalSelection = Selection:Get()

						Selection:Set({})

						-- This doesn't work for some reason x_x
						pluginMouse.Icon = "rbxassetid://7087918593"
						Selection.SelectionChanged:Wait()

						local _, ref = next(Selection:Get())

						instance.__anattaRefs[attributeName].Value = ref
						pluginMouse.Icon = ""
						registry:tryAdd(entity, pendingValidation)
						instance:SetAttribute(attributeName, ref.Parent == nil and "" or ref.Name)

						-- This yield is required to set the selection back to what it was.
						RunService.Heartbeat:Wait()
						Selection:Set(originalSelection)
					else
						registry:tryAdd(entity, pendingValidation)
					end
				end
			end),
		}
	end
end
