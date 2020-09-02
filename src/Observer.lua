local Pool = require(script.Parent.Pool)

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
		constraint.required[i] = manifest:_getPool(id)
		manifest:onAdded(id):connect(constraint:maybeAdd(pool, updated))
		manifest:onRemoved(id):connect(constraint:maybeRemove(pool, updated))
	end

	for i, id in ipairs(constraint.forbidden) do
		constraint.forbidden[i] = manifest:_getPool(id)
		manifest:onRemoved(id):connect(constraint:maybeAdd(pool, updated))
		manifest:onAdded(id):connect(constraint:maybeRemove(pool, updated))
	end

	for _, id in ipairs(constraint.changed) do
		manifest:onUpdated(id):connect(constraint:maybeAdd(pool, updated))
		manifest:onRemoved(id):connect(constraint:maybeRemove(pool, updated))
	end

	return obsId
end

function Observer:maybeAdd(obsPool, updated)
	local required = self.required
	local forbidden = self.forbidden
	local numChanged = #self.changed

	if numChanged > 0 then
		return function(entity)
			for _, pool in ipairs(forbidden) do
				if pool.sparse[entity] then
					return
				end
			end

			for _, pool in ipairs(required) do
				if not pool.sparse[entity] then
					return
				end
			end

			local val = (updated[entity] or 0) + 1

			updated[entity] = val

			if not obsPool:has(entity) and val == numChanged then
				obsPool:assign(entity)
				obsPool.onAdd:dispatch(entity)
			end
		end
	end

	return function(entity)
		for _, pool in ipairs(forbidden) do
			if pool.sparse[entity] then
				return
			end
		end

		for _, pool in ipairs(required) do
			if not pool.sparse[entity] then
				return
			end
		end

		if not obsPool:has(entity) then
			obsPool:assign(entity)
			obsPool.onAdd:dispatch(entity)
		end
	end
end

function Observer:maybeRemove(obsPool, updated)
	local numChanged = #self.changed

	if numChanged > 0 then
		return function(entity)
			if updated[entity] then
				local val = updated[entity] - 1

				if val == 0 then
					updated[entity] = nil
				else
					updated[entity] = val
				end
			end

			if obsPool:has(entity) then
				obsPool.onRemove:dispatch(entity)
				obsPool:destroy(entity)
			end
		end
	end

	return function(entity)
		if obsPool:has(entity) then
			obsPool.onRemove:dispatch(entity)
			obsPool:destroy(entity)
		end
	end
end

return Observer
