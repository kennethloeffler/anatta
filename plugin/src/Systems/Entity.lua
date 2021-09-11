local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local SHARED_INSTANCE_TAG_NAME = Constants.SharedInstanceTagName

return function(system)
	local registry = system.registry
	local forcedEntities = system:all(".anattaInstance", ".anattaForceEntityAttribute"):collect()
	local instances = system:all(".anattaInstance"):collect()

	system:on(instances.added, function(entity, instance)
		instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, entity)
		CollectionService:AddTag(instance, SHARED_INSTANCE_TAG_NAME)
	end)

	system:on(instances.removed, function(_, instance)
		instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, nil)
		CollectionService:RemoveTag(instance, SHARED_INSTANCE_TAG_NAME)
	end)

	system:on(RunService.Heartbeat, function()
		forcedEntities:each(function(entity, instance)
			registry:remove(entity, ".anattaForceEntityAttribute")
			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, entity)
		end)
	end)
end
