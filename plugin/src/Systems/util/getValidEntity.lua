local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Parent.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

return function(registry, instance)
	local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

	assert(entity == nil or typeof(entity) == "number")

	if
		entity == nil
		or (registry:valid(entity) and registry:get(entity, ".anattaInstance") ~= instance)
		or not registry:valid(entity)
	then
		local newEntity = registry:create()

		instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, newEntity)

		CollectionService:AddTag(instance, ".anattaInstance")
		registry:add(newEntity, ".anattaInstance", instance)

		return newEntity
	else
		return entity
	end
end
