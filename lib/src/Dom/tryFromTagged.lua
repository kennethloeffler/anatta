local CollectionService = game:GetService("CollectionService")

local util = require(script.Parent.Parent.util)

local tryFromAttributes = require(script.Parent.tryFromAttributes)

return function(pool)
	util.jumpAssert(pool.size == 0, "Pool must be empty")

	local definition = pool.componentDefinition
	local tagged = CollectionService:GetTagged(componentName)
	local taggedCount = #tagged

	pool.dense = table.create(taggedCount)
	pool.components = table.create(taggedCount)

	for _, instance in ipairs(tagged) do
		local success, entity, component = tryFromAttributes(instance, definition)

		if not success then
			warn(("%s failed attribute validation for %s"):format(
				instance:GetFullName(),
				componentName
			))
			continue
		end

		pool:insert(entity, component)
	end

	return true, pool
end
