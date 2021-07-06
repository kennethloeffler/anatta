local RunService = game:GetService("RunService")

local util = require(script.Parent.Parent.Parent.Parent.Anatta.Library.util)

local ValidationListener = {}

function ValidationListener.init(system, registry, componentName)
	local typeDefinition = registry:getDefinition(componentName)
	local listeningTo = system
		:all(componentName, "__anattaInstance", "__anattaPendingValidation")
		:collect()

	system:on(RunService.Heartbeat, function()
		listeningTo:each(function(entity, component, instance)
			local success, result = util.tryFromAttribute(instance, componentName, typeDefinition)

			if not success then
				-- tryToAttribute will always succeed here because all data in a registry
				-- must be valid.
				local _, attributeMap =
					util.tryToAttribute(component, componentName, typeDefinition)

				for name, value in pairs(attributeMap) do
					instance:SetAttribute(name, value)
				end

				if result then
					warn(result)
				end
			else
				registry:replace(entity, componentName, result)
			end

			registry:remove(entity, "__anattaPendingValidation")
		end)
	end)
end

return ValidationListener
