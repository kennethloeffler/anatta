local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Core.Constants)

local tryFromAttribute = require(script.Parent.tryFromAttribute)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

-- Populates a pool with attribute data from the Roblox DataModel by getting all instances
-- tagged with the pool's name and attempting to convert their attributes into entities
-- and components of the pool's type.

-- If a component conversion fails, the entire function fails. However, it is not a hard
-- failure for an entity attribute to be invalid; if an entity attribute is invalid, the
-- function skips it and prints a warning.
return function(pool)
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

		local success, componentResult = tryFromAttribute(instance, componentName, typeDefinition)

		if not success then
			return false, (("Type check failed for entity %s's %s: %s"):format(
				entity,
				componentName,
				componentResult
			))
		else
			pool:insert(entity, componentResult)
		end
	end

	return true, pool
end
