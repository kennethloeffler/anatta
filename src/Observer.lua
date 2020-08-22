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

	for _, id in ipairs(constraint.required) do
		manifest:addedSignal(id):connect(constraint:maybeAdd(pool, updated))
		manifest:removedSignal(id):connect(constraint:maybeRemove(pool, updated))
	end

	for _, id in ipairs(constraint.forbidden) do
		manifest:removedSignal(id):connect(constraint:maybeAdd(pool, updated))
		manifest:addedSignal(id):connect(constraint:maybeRemove(pool, updated))
	end

	for _, id in ipairs(constraint.changed) do
		manifest:updatedSignal(id):connect(constraint:maybeAdd(pool, updated))
		manifest:removedSignal(id):connect(constraint:maybeRemove(pool, updated))
	end

	return obsId
end

function Observer:maybeAdd(pool, updated)
	local manifest = self.manifest
	local required = self.required
	local forbidden = self.forbidden
	local numChanged = #self.changed

	if numChanged > 0 then
		return function(entity)
			if not manifest:has(entity, unpack(required))
			or manifest:any(entity, unpack(forbidden)) then
				return
			end

			local val = (updated[entity] or 0) + 1

			updated[entity] = val

			if not pool:has(entity) and val == numChanged then
				pool:assign(entity)
				pool.onAssign:dispatch(entity)
			end
		end
	end

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

function Observer:maybeRemove(pool, updated)
	local numChanged = #self.changed

	if numChanged > 0 then
		return function(entity)
			if updated[entity] then
				local val = updated[entity] - 1

				if value == 0 then
					updated[entity] = nil
				else
					updated[entity] = val
				end
			end

			if pool:has(entity) then
				pool.onRemove:dispatch(entity)
				pool:destroy(entity)
			end
		end
	end

	return function(entity)
		if pool:has(entity) then
			pool.onRemove:dispatch(entity)
			pool:destroy(entity)
		end
	end
end

return Observer
