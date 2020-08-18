local ErrAlreadyHas = "entity %08X already has a %s"
local ErrBadArg = "bad argument #%s (expected %s, got %s)"
local ErrBadComponentId = "invalid component identifier: %s"
local ErrBadType = "bad component type: expected %s, got %s"
local ErrInvalid = "entity %08X either does not exist or it has been destroyed"
local ErrMissing = "entity %08X does not have a %s"

local function componentTypeOk(underlyingType, component)
	local ty = typeof(component)
	local instanceTypeOk = false

	if ty == "Instance" then
		instanceTypeOk = component:IsA(underlyingType)
	end

	return (tostring(underlyingType) == ty) or instanceTypeOk,
	ErrBadType:format(tostring(underlyingType), typeof(component))
end

local function assert(cond, msg, ...)
	if cond then
		return
	end

	error(select(1, ...) ~= nil and msg:format(...) or msg:format("nil"), 3)
end

return function(ecs)
	local strict = {
		T = function(self, name)
			return ecs:T(name)
		end,

		context = function(self, context, value)
			return ecs:context(context, value)
		end,

		numEntities = function()
			return ecs:numEntities()
		end,

		assign = function(_, entities, id, component, ...)
			return ecs:assign(entities, id, component, ...)
		end,

		stub = function(_, entity)
			return ecs:stub(entity)
		end,

		create = function()
			return ecs:create()
		end,

		createFrom = function(_, entity)
			return ecs:createFrom(entity)
		end,

		define = function(_, typeName, name)
			return ecs:define(typeName, name)
		end,

		new = function()
			return ecs.new()
		end,

		all = function(_, ...)
			return ecs:all(...)
		end,

		except = function(_, ...)
			return ecs:except(...)
		end,

		updated = function(_, ...)
			return ecs:updated(...)
		end,

		destroy = function(_, entity)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)

			return ecs:destroy(entity)
		end,

		valid = function(_, entity)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))

			return ecs:valid(entity)
		end,

		has = function(_, entity, ...)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)

			for i = 1, select("#", ...) do
				assert(ecs.pools[select(i, ...)], ErrBadComponentId, select(i, ...))
			end

			return ecs:has(entity, ...)
		end,

		any = function(_, entity, ...)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)

			for i = 1, select("#", ...) do
				assert(ecs.pools[select(i, ...)], ErrBadComponentId, select(i, ...))
			end

			return ecs:any(entity, ...)
		end,

		get = function(_, entity, id)
			local pool = ecs.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(pool:has(entity), ErrMissing, entity, pool.name)

			return ecs:get(entity, id)
		end,

		getIfHas = function(_, entity, id)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)

			return ecs:getIfHas(entity, id)
		end,

		multiGet = function(_, entity, output, ...)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)

			for i = 1, select("#", ...) do
				assert(ecs.pools[select(i, ...)], ErrBadComponentId, select(i, ...))
			end

			return ecs:multiGet(entity, output, ...)
		end,

		add = function(_, entity, id, component)
			local pool = ecs.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(not pool:has(entity), ErrAlreadyHas, entity, pool.name)
			assert(componentTypeOk(pool.underlyingType, component))

			return ecs:add(entity, id, component)
		end,

		multiAdd = function(_, entity, ...)
			assert(select("#", ...) % 2 == 0, "insufficient arguments")

			return ecs:multiAdd(entity, ...)
		end,

		getOrAdd = function(_, entity, id, component)
			local pool = ecs.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)

			return ecs:getOrAdd(entity, id, component)
		end,

		replace = function(_, entity, id, component)
			local pool = ecs.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(pool:has(entity), ErrMissing, entity, pool.name)
			assert(componentTypeOk(pool.underlyingType, component))

			return ecs:replace(entity, id, component)
		end,

		addOrReplace = function(_, entity, id, component)
			local pool = ecs.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(componentTypeOk(pool.underlyingType, component))

			return ecs:addOrReplace(entity, id, component)
		end,

		remove = function(_, entity, id)
			local pool = ecs.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(pool:has(entity), ErrMissing, entity, id)

			return ecs:remove(entity, id)
		end,

		removeIfHas = function(_, entity, id)
			local pool = ecs.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)

			return ecs:removeIfHas(entity, id)
		end,

		patch = function(_, entity, id, ...)
			local pool = ecs.pools[id]

			assert(select("#", ...) % 2 == 0, "insufficient arguments")
			assert(pool:has(entity), ErrMissing, entity, id)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(ecs:valid(entity), ErrInvalid, entity, id)
			assert(pool, ErrBadComponentId, id)

			return ecs:patch(entity, id, ...)
		end,

		addedSignal = function(_, id)
			local pool = ecs.pools[id]

			assert(pool, ErrBadComponentId, id)

			return ecs:addedSignal(id)
		end,

		removedSignal = function(_, id)
			local pool = ecs.pools[id]

			assert(pool, ErrBadComponentId, id)

			return ecs:removedSignal(id)
		end,

		updatedSignal = function(_, id)
			local pool = ecs.pools[id]

			assert(pool, ErrBadComponentId, id)

			return ecs:updatedSignal(id)
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
	return setmetatable({}, strict)
end
