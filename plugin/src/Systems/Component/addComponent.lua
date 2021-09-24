local CollectionService = game:GetService("CollectionService")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)

return function(registry, componentName, pendingComponentValidation)
	local typeDefinition = registry:getComponentDefinition(componentName)

	return function(entity, instance, component)
		registry:tryRemoveComponent(entity, ".anattaValidationListener")

		local _, attributeMap = Anatta.Dom.tryToAttribute(
			instance,
			component,
			componentName,
			typeDefinition
		)

		CollectionService:AddTag(instance, componentName)

		for attributeName, value in pairs(attributeMap) do
			if typeof(value) ~= "Instance" then
				instance:SetAttribute(attributeName, value)
			else
				if value.Parent == nil then
					instance:SetAttribute(attributeName, instance.Name)
					instance.__anattaRefs[attributeName].Value = instance
					registry:tryAddComponent(entity, pendingComponentValidation)
				else
					instance:SetAttribute(attributeName, value.Name)
				end
			end
		end

		registry:addComponent(entity, ".anattaValidationListener")
		registry:tryRemoveComponent(entity, ".anattaScheduledDestruction")
	end
end
