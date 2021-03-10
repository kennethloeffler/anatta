local Pool = require(script.Parent.Parent.Core.Pool)
local SingleCollection = require(script.Parent.SingleCollection)
local util = require(script.Parent.Parent.util)

local Collection = {}
Collection.__index = Collection

function Collection.new(matcher)
	local numForbidden = matcher._numForbidden
	local numOptional = matcher._numOptional
	local numRequired = matcher._numRequired
	local numUpdated = matcher._numUpdated

	util.assertAtCallSite(
		numRequired > 0 or numUpdated > 0 or numOptional > 0,
		"Collections must be given at least one required, updated, or optional component"
	)

	util.assertAtCallSite(
		numUpdated <= 32,
		"Collections may only track up to 32 updated components"
	)

	if
		numRequired == 1
		and numUpdated == 0
		and numForbidden == 0
		and numOptional == 0
	then
		return SingleCollection.new(unpack(matcher._required))
	end

	local collectionPool = Pool.new()
	local connections = table.create(
		2 * (numRequired + numUpdated + numForbidden)
	)

	local self = setmetatable({
		added = collectionPool.added,
		removed = collectionPool.removed,

		_pool = collectionPool,
		_matcher = matcher,
		_updatedSet = {},
		_connections = connections,
		_numPacked = numRequired + numUpdated + numOptional,
		_packed = table.create(numRequired + numUpdated + numOptional),
		_required = matcher._required,
		_forbidden = matcher._forbidden,
		_updated = matcher._updated,
		_optional = matcher._optional,

		_numRequired = numRequired,
		_numUpdated = numUpdated,
		_allUpdatedSet = bit32.rshift(0xFFFFFFFF, 32 - numUpdated),
	}, Collection)


	for _, pool in ipairs(matcher.required) do
		table.insert(self._connections, pool.added:connect(self:_tryAdd()))
		table.insert(self._connections, pool.removed:connect(self:_tryRemove()))
	end

	for i, pool in ipairs(matcher.update) do
		table.insert(self._connections, pool.updated:connect(self:_tryAddUpdated(i - 1)))
		table.insert(self._connections, pool.removed:connect(self:_tryRemoveUpdated(i - 1)))
	end

	for _, pool in ipairs(matcher.forbidden) do
		table.insert(self._connections, pool.added:connect(self:_tryRemove()))
		table.insert(self._connections, pool.removed:connect(self:_tryAdd()))
	end

	for _, pool in ipairs(matcher.optional) do
		table.insert(self._connections, pool.added:connect(self:_tryAdd()))
	end

	return self
end

--[[
	Applies the callback to each tracked entity and its components. Passes the
	entity first, followed by its required, updated, and optional components (in
	that order).
]]
function Collection:each(callback)
	local dense = self._pool.dense
	local sparse = self._pool.sparse
	local packed = self._packed
	local numPacked = self._numPacked
	local updatedSet = self._updatedSet

	for i = self._pool.size, 1, -1 do
		local entity = dense[i]

		dense[i] = nil
		sparse[i] = nil
		updatedSet[entity] = nil

		self:_pack(entity)
		callback(entity, unpack(packed, 1, numPacked))
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
		packed[i + numRequired + numUpdated] = pool:get(entity)
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
		local component = pool:get(entity)

		if not component then
			return false
		end

		packed[i] = component
	end

	local numRequired = self._numRequired
	local numUpdated = self._numUpdated

	for i, pool in ipairs(self._updated) do
		local component = pool:get(entity)

		if not component then
			return false
		end

		packed[numRequired + i] = component
	end

	for i, pool in ipairs(self._optional) do
		packed[numRequired + numUpdated + i] = pool:get(entity)
	end

	return true
end

function Collection:_tryAdd()
	return function(entity)
		if not self._pool:getIndex(entity) and self:_tryPack(entity) then
			self._pool:insert(entity)
			self._pool.added:dispatch(entity, unpack(self._packed, 1, self._numPacked))
		end
	end
end

function Collection:_tryAddUpdated(offset)
	local mask = bit32.lshift(1, offset)

	return function(entity)
		self._updatedSet[entity] = bit32.bor(mask, self._updatedSet[entity] or 0)

		if not self._pool:getIndex(entity) and self:_tryPack(entity) then
			self._pool:insert(entity)
			self._pool.added:dispatch(entity, unpack(self._packed, 1, self._numPacked))
		end
	end
end

function Collection:_tryRemove()
	return function(entity)
		if self._pool:getIndex(entity) then
			self:_pack(entity)
			self._pool.removed:dispatch(entity, unpack(self._packed, 1, self._numPacked))
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
			self._pool.removed:dispatch(entity, unpack(self._packed, 1, self._numPacked))
			self._pool:delete(entity)
		end
	end
end

return Collection
