--[[

  Helper class for observers

]]
local SparseSet = require(script.Parent.SparseSet)

local remove = SparseSet.remove
local insert = SparseSet.insert
local has = SparseSet.has

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
		return function(entity)
			if not has(pool, entity) then
				insert(pool, entity)
			end
		end
	end

	return function(entity)
		if manifest:has(entity, unpack(required)) and not manifest:any(entity, unpack(forbidden)) then
			if not has(pool, entity) then
				insert(pool, entity)
			end
		end
	end
end

local function maybeRemove(pool)
	return function(entity)
		if has(pool, entity) then
			remove(pool, entity)
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
		replaced = {}
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

function Match:replaced(...)
	append({ ... }, self.replaced)

	return self
end

function Match:__call()
	local required = self.required
	local forbidden = self.forbidden
	local manifest = self.manifest
	local pool = self.pool

	for _, reqId in ipairs(required) do
		manifest:assigned(reqId):connect(maybeAdd(manifest, required, forbidden, pool))
		manifest:removed(reqId):connect(maybeRemove(pool))
	end

	for _, forId in ipairs(forbidden) do
		manifest:removed(forId):connect(maybeAdd(manifest, required, forbidden, pool))
		manifest:assigned(forId):connect(maybeRemove(pool))
	end

	for _, repId in ipairs(self.replaced) do
		self:replaced(repId):connect(maybeAdd(manifest, required, forbidden, pool))
		self:removed(repId):connect(maybeRemove(pool))
	end

	return self.id
end

return Match
