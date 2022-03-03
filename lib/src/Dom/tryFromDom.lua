local Constants = require(script.Parent.Parent.Core.Constants)

local tryFromTagged = require(script.Parent.tryFromTagged)
local jumpAssert = require(script.Parent.Parent.util.jumpAssert)

local ENTITYID_MASK = Constants.EntityIdMask

return function(registry, ancestorsToIgnore)
	jumpAssert(registry._size == 0, "Registry must be empty")

	local entitySet = {}

	for definition, pool in pairs(registry._pools) do
		if definition.name:sub(1, 1) == "." then
			continue
		end

		local success, result = tryFromTagged(pool, ancestorsToIgnore)

		if success then
			for _, entity in ipairs(pool.dense) do
				entitySet[entity] = true
			end
		else
			warn(result)
		end
	end

	-- There is a bit of trickery going on here. A simple traversal over entitySet,
	-- calling createEntityFrom on each entity, does work - but it is unordered. If
	-- createFrom is given an entity that is out of range, it must backfill _entities with
	-- recyclable IDs. When entities with the same ID are later encountered at some point
	-- later during the iteration, createEntityFrom linearly searches the recyclable
	-- list. It likely contains many elements in such a scenario, so this can become
	-- fairly costly overall.

	-- To get around this, we create an intermediate list of entities and sort it by its
	-- entity ID field. This results in an ordering identical to the eventual registry. In
	-- this scenario, createEntityFrom backfills less often and the recyclable list is kept
	-- smaller.
	local entities = {}

	for entity in pairs(entitySet) do
		table.insert(entities, entity)
	end

	table.sort(entities, function(lhs, rhs)
		return bit32.band(lhs, ENTITYID_MASK) < bit32.band(rhs, ENTITYID_MASK)
	end)

	for _, entity in ipairs(entities) do
		registry:createEntityFrom(entity)
	end

	for _, pool in pairs(registry._pools) do
		for _, entity in ipairs(pool.dense) do
			pool.added:dispatch(entity, pool:get(entity))
		end
	end
end
