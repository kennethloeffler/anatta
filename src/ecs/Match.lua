--[[

  Helper class for observers

]]
local Match = {}
Match.__index = Match

local move = table.move
	and table.move
	or function(t1, f, e, t, t2)
		for i = f, e do
			t2[t] = t1[i]
			t = t + 1
		end
		return t2
	end

local function append(source, destination)
	move(source, 1, #source, #destination + 1, destination)
end

local function maybeAdd(manifest, required, forbidden, pool)
	if #required == 0 and #forbidden == 0 then
		-- the observer is only watching updated components, so it only needs
		-- to check that it hasn't already captured the entity in question
		return function(entity)
			if not pool:has(entity) then
				pool:assign(entity)
				pool.onAssign:dispatch(entity)
			end
		end
	end

	return function(entity)
		if manifest:has(entity, unpack(required)) and not manifest:any(entity, unpack(forbidden)) then
			if not pool:has(entity) then
				pool:assign(entity)
				pool.onAssign:dispatch(entity)
			end
		end
	end
end

local function maybeRemove(pool)
	return function(entity)
		if pool:has(entity) then
			pool.onRemove:dispatch(entity)
			pool:destroy(entity)
		end
	end
end

function Match.new(manifest, id, pool)
	return setmetatable({
		manifest = manifest,
		id = id,
		pool = pool,
		required = {},
		forbidden = {},
		changed = {}
	}, Match)
end

function Match:all(...)
	append({ ... }, self.required)

	return self
end

function Match:except(...)
	append({ ... }, self.forbidden)

	return self
end

function Match:updated(...)
	append({ ... }, self.changed)

	return self
end

function Match:__call()
	local required = self.required
	local forbidden = self.forbidden
	local manifest = self.manifest
	local pool = self.pool

	for _, id in ipairs(required) do
		manifest:added(id):connect(maybeAdd(manifest, required, forbidden, pool))
		manifest:removed(id):connect(maybeRemove(pool))
	end

	for _, id in ipairs(forbidden) do
		manifest:removed(id):connect(maybeAdd(manifest, required, forbidden, pool))
		manifest:added(id):connect(maybeRemove(pool))
	end

	for _, id in ipairs(self.changed) do
		manifest:updated(id):connect(maybeAdd(manifest, required, forbidden, pool))
		manifest:removed(id):connect(maybeRemove(pool))
	end

	return self.id
end

return Match
