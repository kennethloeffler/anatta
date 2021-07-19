local CollectionService = game:GetService("CollectionService")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)

return function(registry, componentName)
	local typeDefinition = registry:getDefinition(componentName)

	return function(entity, instance, component)
		registry:tryRemove(entity, ".anattaValidationListener")

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
				instance:SetAttribute(attributeName, value:GetFullName())
			end
		end

		registry:add(entity, ".anattaValidationListener")
		registry:tryRemove(entity, ".anattaScheduledDestruction")
	end
end
