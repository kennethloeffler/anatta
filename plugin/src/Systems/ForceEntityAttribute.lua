local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

return function(system, registry)
	local forcedEntities = system:all("__anattaInstance", "__anattaForceEntityAttribute"):collect()

	system:on(RunService.Heartbeat, function()
		forcedEntities:each(function(entity, instance)
			registry:remove(entity, "__anattaForceEntityAttribute")
			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, entity)
		end)
	end)
end
