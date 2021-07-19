local RunService = game:GetService("RunService")

local validate = require(script.validate)

return function(system, registry, componentName, pendingComponentValidation)
	local pendingValidations = system
		:all(componentName, ".anattaInstance", pendingComponentValidation)
		:collect()

	local doValidation = validate(registry, componentName, pendingComponentValidation)

	system:on(RunService.Heartbeat, function()
		pendingValidations:each(doValidation)
	end)
end
