local Constants = require(script.Parent.Parent.Parent.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

return function(registry, instance)
	local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

	if typeof(entity) == "number" and registry:valid(entity) then
		return true, entity
	else
		return false
	end
end
