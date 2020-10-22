local Constants = require(script.Parent.Core).Constants
local Pool = require(script.Parent.Pool)

local ENTITYID_MASK = Constants.ENTITYID_MASK

local Observer = {}
Observer.__index = Observer

function Observer.new(constraint, name)
	local manifest = constraint.manifest
	local obsName = name or string.format("__observer%s", #manifest.pools + 1)
	local obsId = manifest.ident:generate(obsName)
	local pool = Pool.new(obsName)
	local updated = {}

	manifest.pools[obsId] = pool
	setmetatable(constraint, Observer)

	for i, id in ipairs(constraint.required) do
		constraint.required[i] = manifest:getPool(id)
		manifest:onAdded(id):connect(constraint:tryAdd(pool, updated))
		manifest:onRemoved(id):connect(constraint:tryRemove(pool, updated))
	end

	for i, id in ipairs(constraint.forbidden) do
		constraint.forbidden[i] = manifest:getPool(id)
		manifest:onRemoved(id):connect(constraint:tryAdd(pool, updated))
		manifest:onAdded(id):connect(constraint:tryRemove(pool, updated))
	end

	for _, id in ipairs(constraint.changed) do
		manifest:onUpdated(id):connect(constraint:tryAdd(pool, updated, true))
		manifest:onRemoved(id):connect(constraint:tryRemove(pool, updated))
	end

	return obsId
end

function Observer:tryAdd(obsPool, updated, isUpdateSignal)
	local required = self.required
	local forbidden = self.forbidden
	local numChanged = #self.changed

	if numChanged > 0 then
		return function(entity)
			local entityId = bit32.band(entity, ENTITYID_MASK)

			for _, pool in ipairs(forbidden) do
				if pool.sparse[entityId] ~= nil then
					return
				end
			end

			for _, pool in ipairs(required) do
				if pool.sparse[entityId] == nil then
					return
				end
			end

			if isUpdateSignal then
				updated[entityId] = (updated[entityId] or 0) + 1
			end

			if obsPool.sparse[entityId] == nil and updated[entityId] == numChanged then
				obsPool:assign(entity)
				obsPool.onAdd:dispatch(entity)
			end
		end
	end

	return function(entity)
		local entityId = bit32.band(entity, ENTITYID_MASK)

		for _, pool in ipairs(forbidden) do
			if pool.sparse[entityId] ~= nil then
				return
			end
		end

		for _, pool in ipairs(required) do
			if pool.sparse[entityId] == nil then
				return
			end
		end

		if obsPool.sparse[entityId] == nil then
			obsPool:assign(entity)
			obsPool.onAdd:dispatch(entity)
		end
	end
end

function Observer:tryRemove(obsPool, updated)
	local numChanged = #self.changed

	if numChanged > 0 then
		return function(entity)
			local entityId = bit32.band(entity, ENTITYID_MASK)

			if updated[entityId] ~= nil then
				local val = updated[entity] - 1

				if val == 0 then
					updated[entityId] = nil
				else
					updated[entityId] = val
				end
			end

			if obsPool.sparse[entityId] ~= nil then
				obsPool.onRemove:dispatch(entity)
				obsPool:destroy(entity)
			end
		end
	end

	return function(entity)
		if obsPool.sparse[bit32.band(entity, ENTITYID_MASK)] ~= nil then
			obsPool.onRemove:dispatch(entity)
			obsPool:destroy(entity)
		end
	end
end

return Observer
