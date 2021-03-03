local Pool = require(script.Parent.Parent.Core.Pool)
local SingleCollection = require(script.Parent.SingleCollection)
local util = require(script.Parent.Parent.util)

local None = util.createSymbol("None")

local Collection = {}
Collection.__index = Collection

function Collection.new(registry, components)
	local required = registry:getPools(unpack(components.all or None))
	local forbidden = registry:getPools(unpack(components.never or None))
	local updated = registry:getPools(unpack(components.updated or None))
	local optional = registry:getPools(unpack(components.any or None))

	util.assertAtCallSite(
		next(required) or next(updated) or next(optional),
		"Collections must be given at least one required, updated, or optional component"
	)
	util.assertAtCallSite(
		#updated <= 32,
		"Collections may only track up to 32 updated components"
	)

	if
		not next(updated)
		and not next(forbidden)
		and not next(optional)
		and #required == 1
	then
		-- The collection is tracking entities with just one required component. This is
		-- a case we should optimize for. It does not require any additional state and
		-- amounts to an iterating over one pool and connecting to one set of signals.
		return SingleCollection.new(unpack(required))
	end

	local collectionPool = Pool.new()
	local connections = table.create(2 * (#required + #updated + #forbidden))

	local self = setmetatable({
		none = None,
		onAdded = collectionPool.onAdded,
		onRemoved = collectionPool.onRemoved,

		_pool = collectionPool,
		_updatedSet = {},
		_connections = connections,
		_packed = table.create(#required + #updated),

		_required = required,
		_forbidden = forbidden,
		_updated = updated,
		_optional = optional,

		_numRequired = #required,
		_numUpdated = #updated,
		_allUpdatedSet = bit32.rshift(0xFFFFFFFF, 32 - #updated),
	}, Collection)


	for _, pool in ipairs(required) do
		table.insert(connections, pool.onAdded:connect(self:_tryAdd()))
		table.insert(connections, pool.onRemoved:connect(self:_tryRemove()))
	end

	for i, pool in ipairs(updated) do
		table.insert(connections, pool.onUpdated:connect(self:_tryAddUpdated(i - 1)))
		table.insert(connections, pool.onRemoved:connect(self:_tryRemoveUpdated(i - 1)))
	end

	for _, pool in ipairs(forbidden) do
		table.insert(connections, pool.onAdded:connect(self:_tryRemove()))
		table.insert(connections, pool.onRemoved:connect(self:_tryAdd()))
	end

	return self
end

--[[
	Applies the callback to each tracked entity and its components. Passes the entity
	first, followed by its required, updated, and optional components (in that order),
	each in the same order they were given to the collection.
]]
function Collection:each(callback)
	local dense = self._pool.dense

	if next(self._updated) then
		local updatedSet = self._updatedSet
		local sparse = self._pool.sparse

		for i = self._pool.size, 1, -1 do
			local entity = dense[i]

			dense[i] = nil
			sparse[i] = nil
			updatedSet[entity] = nil

			self:_pack(entity)
			callback(entity, unpack(self._packed))
		end
	else
		for i = self._pool.size, 1, -1 do
			local entity = dense[i]

			self:_pack(entity)
			callback(entity, unpack(self._packed))
		end
	end
end

--[[
	Disconnects the collection from the registry, causing it to stop tracking changes.
]]
function Collection:disconnect()
	for _, connection in ipairs(self._connections) do
		connection:disconnect()
	end
end

--[[
	Returns the required component pool with the least number of elements.
]]
function Collection:_getShortestRequiredPool()
	local size = math.huge
	local selected

	for _, pool in ipairs(self._required) do
		if pool.size < size then
			size = pool.size
			selected = pool
		end
	end

	return selected
end

--[[
	Unconditionally fills the collection's _packed field with the entity's required,
	updated, and optional components.
]]
function Collection:_pack(entity)
	local numUpdated = self._numUpdated
	local numRequired = self._numRequired
	local packed = self._packed

	for i, pool in ipairs(self._required) do
		packed[i] = pool:get(entity)
	end

	for i, pool in ipairs(self._updated) do
		packed[i + numRequired] = pool:get(entity)
	end

	for i, pool in ipairs(self._optional) do
		local denseIndex = pool:getIndex(entity)

		if denseIndex then
			packed[i + numRequired + numUpdated] = pool.objects[denseIndex] or None
		else
			packed[i + numRequired + numUpdated] = None
		end
	end
end

--[[
	Returns true and fills the collection's _packed field with entity's required,
	updated, and optional components if the entity fully satisfies the required,
	forbidden and updated predicates. Otherwise, returns false.
]]
function Collection:_tryPack(entity)
	local packed = self._packed

	if (self._updatedSet[entity] or 0) ~= self._allUpdatedSet then
		return false
	end

	for _, pool in ipairs(self._forbidden) do
		if pool:getIndex(entity) then
			return false
		end
	end

	for i, pool in ipairs(self._required) do
		local denseIndex = pool:getIndex(entity)

		if not denseIndex then
			return false
		end

		packed[i] = pool.objects[denseIndex]
	end

	local numRequired = self._numRequired
	local numUpdated = self._numUpdated

	for i, pool in ipairs(self._updated) do
		local denseIndex = pool:getIndex(entity)

		if not denseIndex then
			return false
		end

		packed[numRequired + i] = pool.objects[denseIndex]
	end

	for i, pool in ipairs(self._optional) do
		local denseIndex = pool:getIndex(entity)

		if denseIndex then
			packed[numRequired + numUpdated + i] = pool.objects[denseIndex] or None
		else
			packed[numRequired + numUpdated + i] = None
		end
	end

	return true
end

function Collection:_tryAdd()
	return function(entity)
		if not self._pool:getIndex(entity) and self:_tryPack(entity) then
			self._pool:insert(entity)
			self._pool.onAdded:dispatch(entity, unpack(self._packed))
		end
	end
end

function Collection:_tryAddUpdated(offset)
	local mask = bit32.lshift(1, offset)

	return function(entity)
		self._updatedSet[entity] = bit32.bor(mask, self._updatedSet[entity] or 0)

		if not self._pool:getIndex(entity) and self:_tryPack(entity) then
			self._pool:insert(entity)
			self._pool.onAdded:dispatch(entity, unpack(self._packed))
		end
	end
end

function Collection:_tryRemove()
	return function(entity)
		if self._pool:getIndex(entity) then
			self:_pack(entity)
			self._pool.onRemoved:dispatch(entity, unpack(self._packed))
			self._pool:delete(entity)
		end
	end
end

function Collection:_tryRemoveUpdated(offset)
	local mask = bit32.bnot(bit32.lshift(1, offset))

	return function(entity)
		local updates = self._updatedSet[entity]

		if updates then
			local newUpdates = bit32.band(updates, mask)

			if newUpdates == 0 then
				self._updatedSet[entity] = nil
			else
				self._updatedSet[entity] = newUpdates
			end
		end

		if self._pool:getIndex(entity) then
			self:_pack(entity)
			self._pool.onRemoved:dispatch(entity, unpack(self._packed))
			self._pool:delete(entity)
		end
	end
end

return Collection
