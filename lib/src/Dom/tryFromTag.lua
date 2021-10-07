local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Core.Constants)
local util = require(script.Parent.Parent.util)

local tryFromAttribute = require(script.Parent.tryFromAttribute)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

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

		local componentSuccess, componentResult = tryFromAttribute(
			instance,
			componentName,
			typeDefinition
		)

		if not componentSuccess then
			warn(("Instance %s failed attribute validation for %s"):format(
				instance:GetFullName(),
				componentName
			))
		end

		pool:insert(entity, componentResult)
	end

	return true, pool
end
