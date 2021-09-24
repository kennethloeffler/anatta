local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Core.Constants)
local util = require(script.Parent.Parent.util)

local tryFromAttribute = require(script.Parent.tryFromAttribute)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

-- Attempts to convert attributes from Instances tagged with an empty Pool's name into
-- entities and components of the correct type.

-- Throws If an attribute(s) -> component conversion fails (it's likely that the entire
-- set of attributes is bad in this case). It is not a an error for only the entity
-- attribute is invalid; instead, a warning is printed.
return function(pool)
	util.jumpAssert(pool.size == 0, "Pool must be empty")

	local componentName = pool.name
	local typeDefinition = pool.typeDefinition
	local tagged = CollectionService:GetTagged(componentName)
	local taggedCount = #tagged

	pool.dense = table.create(taggedCount)
	pool.components = table.create(taggedCount)

	for _, instance in ipairs(tagged) do
		local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

		if entity == nil or typeof(entity) ~= "number" then
			warn(("Instance %s did not have a valid entity attribute"):format(instance:GetFullName()))
			continue
		end

		local success, component = tryFromAttribute(instance, componentName, typeDefinition)

		if not success then
			pool.size = 0
			pool.sparse = {}

			return false, (("Type check failed for entity %s's %s: %s"):format(
				entity,
				componentName,
				component
			))
		else
			local conversion = pool.meta and pool.meta.plugin and pool.meta.plugin.conversion

			pool:insert(entity, component)
		end
	end

	return true, pool
end
