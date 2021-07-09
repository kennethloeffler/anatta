local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Core.Constants)

local tryFromAttribute = require(script.Parent.tryFromAttribute)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

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
