local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Core.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local ENTITY_TAG_NAME = Constants.EntityTagName

return function(registry)
	local entities = {}

	for _, instance in ipairs(CollectionService:GetTagged(ENTITY_TAG_NAME)) do
		local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

		if typeof(entity) ~= "number" then
			warn(("bad entity attribute for %s: number expected, got %s"):format(
				instance:GetFullName(),
				typeof(entity)
			))
		end

		table.insert(entities, entity)
	end

	table.sort(entities)

	for _, entity in ipairs(entities) do
		registry:createEntityFrom(entity)
	end
end
