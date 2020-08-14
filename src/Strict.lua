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

	error(msg:format(...), 3)
end

return function(ecs)
	local mt = getmetatable(ecs)

	local newMt = {
		context = mt.context,
		numEntities = mt.numEntities,
		assign = mt.assign,
		stub = mt.stub,
		create = mt.create,
		createFrom = mt.createFrom,
		define = mt.define,
		new = mt.new,
		all = mt.all,
		except = mt.except,
		updated = mt.updated,

		destroy = function(self, entity)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)

			return mt.destroy(self, entity)
		end,

		valid = function(self, entity)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))

			return mt.valid(self, entity)
		end,

		has = function(self, entity, ...)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)

			for i = 1, select("#", ...) do
				assert(self.pools[select(i, ...)], ErrBadComponentId, select(i, ...))
			end

			return mt.has(self, entity, ...)
		end,

		any = function(self, entity, ...)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)

			for i = 1, select("#", ...) do
				assert(self.pools[select(i, ...)], ErrBadComponentId, select(i, ...))
			end

			return mt.any(self, entity, ...)
		end,

		get = function(self, entity, id)
			local pool = self.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(pool:has(entity), ErrMissing, entity, pool.name)

			return mt.get(self, entity, id)
		end,

		getIfHas = function(self, entity, id)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)

			return mt.getIfHas(self, entity, id)
		end,

		multiGet = function(self, entity, output, ...)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)

			for i = 1, select("#", ...) do
				assert(self.pools[select(i, ...)], ErrBadComponentId, select(i, ...))
			end

			return mt.multiGet(self, entity, output, ...)
		end,

		add = function(self, entity, id, component)
			local pool = self.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(not pool:has(entity), ErrAlreadyHas, entity, pool.name)
			assert(componentTypeOk(pool.underlyingType, component))

			return mt.add(self, entity, id, component)
		end,

		multiAdd = function(self, entity, ...)
			assert(select("#", ...) % 2 == 0, "insufficient arguments")

			return mt.multiAdd(self, entity, ...)
		end,

		getOrAdd = function(self, entity, id, component)
			local pool = self.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)

			return mt.getOrAdd(self, entity, id, component)
		end,

		replace = function(self, entity, id, component)
			local pool = self.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(pool:has(entity), ErrMissing, entity, pool.name)
			assert(componentTypeOk(pool.underlyingType, component))

			return mt.replace(self, entity, id, component)
		end,

		addOrReplace = function(self, entity, id, component)
			local pool = self.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(componentTypeOk(pool.underlyingType, component))

			return mt.addOrReplace(self, entity, id, component)
		end,

		remove = function(self, entity, id)
			local pool = self.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)
			assert(pool:has(entity), ErrMissing, entity, id)

			return mt.remove(self, entity, id)
		end,

		removeIfHas = function(self, entity, id)
			local pool = self.pools[id]

			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity)
			assert(pool, ErrBadComponentId, id)

			return mt.removeIfHas(self, entity, id)
		end,

		patch = function(self, entity, id, ...)
			local pool = self.pools[id]

			assert(select("#", ...) % 2 == 0, "insufficient arguments")
			assert(pool:has(entity), ErrMissing, entity, id)
			assert(type(entity) == "number", ErrBadArg, 1, "number", type(entity))
			assert(mt.valid(self, entity), ErrInvalid, entity, id)
			assert(pool, ErrBadComponentId, id)

			return mt.patch(self, entity, id, ...)
		end,

		addedSignal = function(self, id)
			local pool = self.pools[id]

			assert(pool, ErrBadComponentId, id)

			return mt.addedSignal(self, id)
		end,

		removedSignal = function(self, id)
			local pool = self.pools[id]

			assert(pool, ErrBadComponentId, id)

			return mt.removedSignal(self, id)
		end,

		updatedSignal = function(self, id)
			local pool = self.pools[id]

			assert(pool, ErrBadComponentId, id)

			return mt.updatedSignal(self, id)
		end,

		poolSize = function(self, id)
			assert(self.pools[id], ErrBadComponentId, id)

			return mt.poolSize(self, id)
		end,

		_getPool = function(self, id)
			assert(self.pools[id], ErrBadComponentId, id)

			return mt._getPool(self, id)
		end
	}

	newMt.__index = newMt

	return setmetatable(ecs, newMt)
end
