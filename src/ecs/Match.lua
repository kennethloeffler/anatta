local Pool = require(script.Parent.Pool)

local assign = Pool.assign
local destroy = Pool.destroy
local get = Pool.get

local OBS_REQUIRE = 0
local OBS_FORBID = 1
local OBS_REPLACED = 2

local Match = {}
Match.__index = Match

local function append(source, destination)
	table.move(source, 1, #source, #destination, destination)
end

function Match.new()
	return setmetatable({
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

function Match:_connect(manifest, pool)
	local required = self.required
	local forbidden = self.forbidden
	local replaced = self.replaced
	local has = manifest.has
	local any = manifest.any

	local function maybeAdd(idx)
		return function(entity)
			if has(manifest, entity, unpack(required)) and not any(manifest, entity, unpack(forbidden)) then
				assign(pool, entity,
					bit32.bor(get(pool, entity) or assign(pool, entity, 0), bit32.lshift(1, idx)))
			end
		end
	end

	local function maybeRemove(idx)
		return function(entity)
			local flags = get(pool, entity)
			local new = flags and bit32.band(flags, bit32.bnot(bit32.lshift(1, idx)))

			destroy(pool, entity)

			if new ~= 0 then
				assign(pool, entity, new)
			end
		end
	end

	for _, id in ipairs(required) do
		manifest:assigned(id):connect(maybeAdd(OBS_REQUIRE))
		manifest:removed(id):connect(maybeRemove(OBS_REQUIRE))
	end

	for _, id in ipairs(forbidden) do
		manifest:assigned(id):connect(maybeAdd(OBS_FORBID))
		manifest:removed(id):connect(maybeAdd(OBS_FORBID))
	end

	for _, id in ipairs(replaced) do
		manifest:replaced(id):connect(maybeAdd(OBS_REPLACED))
		manifest:removed(id):connect(maybeRemove(OBS_REPLACED))
	end
end

return Match
