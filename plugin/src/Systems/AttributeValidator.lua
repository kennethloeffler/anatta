local RunService = game:GetService("RunService")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)

return function(system, registry, componentName, pendingComponentValidation)
	local typeDefinition = registry:getDefinition(componentName)
	local pendingValidations = system
		:all(componentName, ".anattaInstance", pendingComponentValidation)
		:collect()

	system:on(RunService.Heartbeat, function()
		pendingValidations:each(function(entity, component, instance)
			local success, result = Anatta.Dom.tryFromAttribute(
				instance,
				componentName,
				typeDefinition
			)

			if not success then
				-- tryToAttribute will always succeed here because all data in a registry
				-- must be valid.
				local _, attributeMap = Anatta.Dom.tryToAttribute(
					component,
					componentName,
					typeDefinition
				)

				local wasListening = registry:tryRemove(entity, ".anattaValidationListener")

				for name, value in pairs(attributeMap) do
					instance:SetAttribute(name, value)
				end

				if wasListening then
					registry:add(entity, ".anattaValidationListener")
				end

				if result then
					warn(result)
				end
			else
				registry:replace(entity, componentName, result)
			end

			registry:remove(entity, pendingComponentValidation)
		end)
	end)
end
