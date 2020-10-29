local Core = require(script.Parent.Core)
local Constants = Core.Constants
local TypeDef = Core.TypeDef
local Pool = require(script.Parent.Pool)

local NUM_OBS = 0
local ENTITYID_MASK = Constants.ENTITYID_MASK

local Observer = {}
Observer.__index = Observer

local function hasRequiredAndNoForbidden(entityId, required, forbidden)
	for _, pool in ipairs(forbidden) do
		if pool.sparse[entityId] ~= nil then
			return false
		end
	end

	for _, pool in ipairs(required) do
		if pool.sparse[entityId] == nil then
			return false
		end
	end

	return true
end

local function tryAdd(obsPool, required, forbidden)
	return function(entity)
		local entityId = bit32.band(entity, ENTITYID_MASK)

		if
			obsPool.sparse[entityId] == nil
			and hasRequiredAndNoForbidden(entityId, required, forbidden)
		then
			obsPool:assign(entity)
			obsPool.onAdd:dispatch(entity)
		end
	end
end

local function tryAddHasUpdated(obsPool, required, forbidden, numChanged, updatedEntities)
	return function(entity)
		local entityId = bit32.band(entity, ENTITYID_MASK)

		if
			obsPool.sparse[entityId] == nil
			and updatedEntities[entityId] == numChanged
			and hasRequiredAndNoForbidden(entityId, required, forbidden)
		then
			obsPool:assign(entity)
			obsPool.onAdd:dispatch(entity)
		end
	end
end

local function tryAddOnUpdatedSignal(obsPool, required, forbidden, numChanged, updatedEntities)
	return function(entity)
		local entityId = bit32.band(entity, ENTITYID_MASK)

		updatedEntities[entityId] = (updatedEntities[entityId] or 0) + 1

		if
			obsPool.sparse[entityId] == nil
			and updatedEntities[entityId] == numChanged
			and hasRequiredAndNoForbidden(entityId, required, forbidden)
		then
			obsPool:assign(entity)
			obsPool.onAdd:dispatch(entity)
		end
	end
end

local function tryRemove(obsPool)
	return function(entity)
		if obsPool.sparse[bit32.band(entity, ENTITYID_MASK)] ~= nil then
			obsPool.onRemove:dispatch(entity)
			obsPool:destroy(entity)
		end
	end
end

local function tryRemoveHasUpdated(obsPool, updatedEntities)
	return function(entity)
		local entityId = bit32.band(entity, ENTITYID_MASK)

		if updatedEntities[entityId] ~= nil then
			local numUpdated = updatedEntities[entity] - 1

			if numUpdated == 0 then
				updatedEntities[entityId] = nil
			else
				updatedEntities[entityId] = numUpdated
			end
		end

		if obsPool.sparse[entityId] ~= nil then
			obsPool.onRemove:dispatch(entity)
			obsPool:destroy(entity)
		end
	end
end

function Observer.new(constraint, name)
	local manifest = constraint.manifest
	local required = constraint.required
	local forbidden = constraint.forbidden
	local changed = constraint.changed

	local numChanged = #changed
	local obsName = name or string.format("__observer%s", NUM_OBS + 1)
	local obs = manifest:define {
		name = obsName,
		type = TypeDef.none
	}
	local obsPool = manifest:getPools(obs)[1]
	local updatedEntities = {}
	local add = numChanged ~= 0
		and tryAddHasUpdated(obsPool, required, forbidden, numChanged, updatedEntities)
		or tryAdd(obsPool, required, forbidden)
	local remove = numChanged ~= 0
		and tryRemoveHasUpdated(obsPool, updatedEntities)
		or tryRemove(obsPool)

	manifest.pools[obs] = obsPool

	for _, pool in ipairs(required) do
		pool.onAdd:connect(add)
		pool.onRemove:connect(remove)
	end

	for _, pool in ipairs(constraint.forbidden) do
		pool.onRemove:connect(add)
		pool.onAdd:connect(remove)
	end

	for _, pool in ipairs(constraint.changed) do
		pool.onUpdate:connect(tryAddOnUpdatedSignal(obsPool, required, forbidden, numChanged, updatedEntities))
		pool.onRemove:connect(remove)
	end

	NUM_OBS += 1

	return obs
end

return Observer
