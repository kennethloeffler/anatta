local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)

return function(registry, componentName, pendingComponentValidation)
	local typeDefinition = registry:getComponentDefinition(componentName)

	return function(entity, component, instance)
		local success, result = Anatta.Dom.tryFromAttribute(instance, componentName, typeDefinition)

		if not success then
			-- tryToAttribute will always succeed here because all data in a registry
			-- must be valid.
			local _, attributeMap = Anatta.Dom.tryToAttribute(
				instance,
				component,
				componentName,
				typeDefinition
			)

			local wasListening = registry:tryRemoveComponent(entity, ".anattaValidationListener")

			for name, value in pairs(attributeMap) do
				if typeof(value) ~= "Instance" then
					instance:SetAttribute(name, value)
				else
					instance:SetAttribute(name, value.Parent == nil and "" or value.Name)
				end
			end

			if wasListening then
				registry:addComponent(entity, ".anattaValidationListener")
			end

			if result then
				warn(result)
			end
		else
			registry:replaceComponent(entity, componentName, result)
		end

		registry:removeComponent(entity, pendingComponentValidation)
	end
end
