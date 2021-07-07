local RunService = game:GetService("RunService")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)
local Constants = require(script.Parent.Parent.Parent.Constants)

local PENDING_VALIDATION = Constants.PendingValidation

return function(system, registry, componentName)
	local typeDefinition = registry:getDefinition(componentName)
	local pendingValidation = PENDING_VALIDATION:format(componentName)
	local listeningTo = system
		:all(componentName, "__anattaPluginInstance", pendingValidation)
		:collect()

	system:on(RunService.Heartbeat, function()
		listeningTo:each(function(entity, component, instance)
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

				for name, value in pairs(attributeMap) do
					instance:SetAttribute(name, value)
				end

				if result then
					warn(result)
				end
			else
				registry:replace(entity, componentName, result)
			end

			registry:remove(entity, pendingValidation)
		end)
	end)
end
