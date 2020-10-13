local t = require(script.Parent.core.t)

local ErrAlreadyHas = "entity %08X already has a %s"
local ErrBadArg = "bad argument #%s (expected %s, got %s)"
local ErrBadComponentId = "invalid component identifier: %s"
local ErrBadComponentType = "bad type for %s: %s"
local ErrInvalid = "entity %08X either does not exist or it has been destroyed"
local ErrMissing = "entity %08X does not have a %s"

local function componentTypeOk(pool, component)
	local typeOk, msg = pool.tFunction(component)

	return typeOk, not typeOk and string.format(ErrBadComponentType, pool.name, msg)
end

local function assert(cond, msg, ...)
	if cond then
		return
	end

	error(select(1, ...) ~= nil and string.format(msg, ...) or string.format(msg, "nil"), 3)
end

return function(ecs)
	local strict = {
		T = function(_, name)
			return ecs:T(name)
		end,

		context = function(_, context, value)
			return ecs:context(context, value)
		end,

		numEntities = function()
			return ecs:numEntities()
		end,

		raw = function(_, id)
			assert(ecs.pools[id], ErrBadComponentId, id)

			return ecs:raw(id)
		end,

		assign = function(_, entities, id, component, ...)
			local pool = ecs.pools[id]

			assert(pool, ErrBadComponentId, id)

			for _, entity in ipairs(entities) do
				assert(ecs:valid(entity), ErrInvalid, entity)
			end

			assert(componentTypeOk(pool, component))

			return ecs:assign(entities, id, component, ...)
		end,

		stub = function(_, entity)
			assert(ecs:valid(entity), ErrInvalid, entity)

			return ecs:stub(entity)
		end,

		create = function()
			return ecs:create()
		end,

		createFrom = function(_, entity)
			if ecs:valid(entity) then
				warn(("creating a new entity because %08X's id is already in use - did you mean to do this?"):format(entity))
			end

			return ecs:createFrom(entity)
		end,

		define = function(_, typeName, name)
			return ecs:define(typeName, name)
		end,

		new = function()
			return ecs.new()
		end,

		all = function(_, ...)
			for i = 1, select("#", ...) do
				local id = select(i, ...)

				assert(ecs.pools[id], ErrBadComponentId, id)
			end

			return ecs:all(...)
		end,

		except = function(_, ...)
			for i = 1, select("#", ...) do
				local id = select(i, ...)

				assert(ecs.pools[id], ErrBadComponentId, id)
			end

			return ecs:except(...)
		end,

		updated = function(_, ...)
			for i = 1, select("#", ...) do
				local id = select(i, ...)

				assert(ecs.pools[id], ErrBadComponentId, id)
			end

			return ecs:updated(...)
		end,

		destroy = function(_, entity)
			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)

			return ecs:destroy(entity)
		end,

		valid = function(_, entity)
			assert(t.number(entity))

			return ecs:valid(entity)
		end,

		has = function(_, entity, ...)
			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)

			for i = 1, select("#", ...) do
				assert(ecs.pools[select(i, ...)], ErrBadComponentId, select(i, ...))
			end

			return ecs:has(entity, ...)
		end,

		any = function(_, entity, ...)
			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)

			for i = 1, select("#", ...) do
				assert(ecs.pools[select(i, ...)], ErrBadComponentId, select(i, ...))
			end

			return ecs:any(entity, ...)
		end,

		get = function(_, entity, id)
			local pool = ecs.pools[id]

			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(pool:has(entity), ErrMissing, entity, pool.name)

			return ecs:get(entity, id)
		end,

		maybeGet = function(_, entity, id)
			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(ecs.pools[id], ErrBadComponentId, id)

			return ecs:maybeGet(entity, id)
		end,

		multiGet = function(_, entity, output, ...)
			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)

			for i = 1, select("#", ...) do
				local pool = ecs.pools[select(i, ...)]

				assert(pool, ErrBadComponentId, select(i, ...))
				assert(pool:has(entity), ErrMissing, entity, pool.name)
			end

			return ecs:multiGet(entity, output, ...)
		end,

		add = function(_, entity, id, component)
			local pool = ecs.pools[id]

			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(not pool:has(entity), ErrAlreadyHas, entity, pool.name)
			assert(componentTypeOk(pool, component))

			return ecs:add(entity, id, component)
		end,

		maybeAdd = function(_, entity, id, component)
			local pool = ecs.pools[id]

			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(componentTypeOk(pool, component))

			return ecs:maybeAdd(entity, id, component)
		end,

		multiAdd = function(_, entity, ...)
			assert(select("#", ...) % 2 == 0, "insufficient arguments")
			assert(ecs:valid(entity), ErrInvalid, entity)

			for i = 1, select("#", ...), 2 do
				local pool = ecs.pools[select(i, ...)]

				assert(pool, ErrBadComponentId, select(i, ...))
				assert(not pool:has(entity), ErrAlreadyHas, entity, pool.name)
				assert(componentTypeOk(pool, select(i + 1, ...)))
			end

			return ecs:multiAdd(entity, ...)
		end,

		getOrAdd = function(_, entity, id, component)
			local pool = ecs.pools[id]

			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)

			return ecs:getOrAdd(entity, id, component)
		end,

		replace = function(_, entity, id, component)
			local pool = ecs.pools[id]

			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(pool:has(entity), ErrMissing, entity, pool.name)
			assert(componentTypeOk(pool, component))

			return ecs:replace(entity, id, component)
		end,

		addOrReplace = function(_, entity, id, component)
			local pool = ecs.pools[id]

			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(componentTypeOk(pool, component))

			return ecs:addOrReplace(entity, id, component)
		end,

		remove = function(_, entity, id)
			local pool = ecs.pools[id]

			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(pool:has(entity), ErrMissing, entity, pool.name)

			return ecs:remove(entity, id)
		end,

		multiRemove = function(_, entity, ...)
			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)

			for i = 1, select("#", ...)  do
				local pool = ecs.pools[select(i, ...)]

				assert(pool, ErrBadComponentId, select(i, ...))
				assert(pool:has(entity), ErrMissing, entity, pool.name)
			end

			return ecs:multiRemove(entity, ...)
		end,

		maybeRemove = function(_, entity, id)
			local pool = ecs.pools[id]

			assert(t.number(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)

			return ecs:maybeRemove(entity, id)
		end,

		onAdded = function(_, id)
			local pool = ecs.pools[id]

			assert(pool, ErrBadComponentId, id)

			return ecs:onAdded(id)
		end,

		onRemoved = function(_, id)
			local pool = ecs.pools[id]

			assert(pool, ErrBadComponentId, id)

			return ecs:onRemoved(id)
		end,

		onUpdated = function(_, id)
			local pool = ecs.pools[id]

			assert(pool, ErrBadComponentId, id)

			return ecs:onUpdated(id)
		end,

		poolSize = function(_, id)
			assert(ecs.pools[id], ErrBadComponentId, id)

			return ecs:poolSize(id)
		end,

		_getPool = function(_, id)
			assert(ecs.pools[id], ErrBadComponentId, id)

			return ecs:_getPool(id)
		end
	}

	strict.__index = strict
	return setmetatable({ t = ecs.t }, strict)
end
