local RunService = game:GetService("RunService")

local validate = require(script.validate)

return function(system, componentName, pendingComponentValidation)
	local pendingValidations = system
		:all(componentName, ".anattaInstance", pendingComponentValidation)
		:collect()

	local doValidation = validate(system.registry, componentName, pendingComponentValidation)

	system:on(RunService.Heartbeat, function()
		pendingValidations:each(doValidation)
	end)
end
