local Constants = require(script.Parent.Parent.Parent.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

return function(registry, instance)
	local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

	assert(entity == nil or typeof(entity) == "number")

	local isNil = entity == nil
	local isInvalid = not isNil and not registry:valid(entity)
	local isInvalidInstance = not isNil
		and not isInvalid
		and registry:get(entity, ".anattaInstance") ~= instance

	if isNil or isInvalid or isInvalidInstance then
		local newEntity = registry:create()
		registry:add(newEntity, ".anattaInstance", instance)
		return newEntity
	else
		return entity
	end
end
