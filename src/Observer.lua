local Matcher = require(script.Parent.Matcher)

local Observer = {}
Observer.__index = Matcher

local function maybeAdd(manifest, required, forbidden, pool)
	-- is this observer only watching components that have been updated? if so,
	-- we can just ensure that we haven't already captured this entity and skip
	-- checks for required and forbidden components
	if #required == 0 and #forbidden == 0 then
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

function Observer.new(manifest, id, pool)
	local observer = Matcher.new()

	observer.manifest = manifest
	observer.id = id
	observer.pool = pool

	return setmetatable(observer, Observer)
end

function Observer:__call()
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

return Observer
