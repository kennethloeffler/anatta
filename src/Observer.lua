local Pool = require(script.Parent.Pool)

local Observer = {}
Observer.__index = Observer

function Observer.new(constraint, name)
	local manifest = constraint.manifest
	local obsName = name or string.format("__observer%s", #manifest.pools + 1)
	local obsId = manifest.component:generate(obsName)
	local pool = Pool.new(obsName)

	manifest.pools[obsId] = pool
	setmetatable(constraint, Observer)

	for _, id in ipairs(constraint.required) do
		manifest:addedSignal(id):connect(constraint:maybeAdd(pool))
		manifest:removedSignal(id):connect(constraint:maybeRemove(pool))
	end

	for _, id in ipairs(constraint.forbidden) do
		manifest:removedSignal(id):connect(constraint:maybeAdd(pool))
		manifest:addedSignal(id):connect(constraint:maybeRemove(pool))
	end

	for _, id in ipairs(constraint.changed) do
		manifest:updatedSignal(id):connect(constraint:maybeAdd(pool))
		manifest:removedSignal(id):connect(constraint:maybeRemove(pool))
	end

	return obsId
end

function Observer:maybeAdd(pool)
	local manifest = self.manifest
	local required = self.required
	local forbidden = self.forbidden

	return function(entity)
		if not manifest:has(entity, unpack(required))
		or manifest:any(entity, unpack(forbidden)) then
			return
		end

		if not pool:has(entity) then
			pool:assign(entity)
			pool.onAssign:dispatch(entity)
		end
	end
end

function Observer:maybeRemove(pool, observed)
	return function(entity)
		if pool:has(entity) then
			pool.onRemove:dispatch(entity)
			pool:destroy(entity)
		end
	end
end

return Observer
