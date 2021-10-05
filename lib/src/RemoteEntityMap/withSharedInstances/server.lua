local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Parent.Core.Constants)
local t = require(script.Parent.Parent.Parent.Core.TypeDefinition)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local SHARED_INSTANCE_TAG_NAME = Constants.SharedInstanceTagName

return function(remoteEntityMap)
	local registry = remoteEntityMap.registry
	local sharedInstances = CollectionService:GetTagged(SHARED_INSTANCE_TAG_NAME)

	registry:define("SharedInstance", t.Instance)

	for _, instance in ipairs(sharedInstances) do
		local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)
		registry:add(entity, "SharedInstance", instance)
	end
end
