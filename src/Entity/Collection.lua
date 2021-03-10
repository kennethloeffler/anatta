local Attachments = require(script.Parent.Attachments)
local Pool = require(script.Parent.Parent.Core.Pool)
local SingleCollection = require(script.Parent.SingleCollection)
local util = require(script.Parent.Parent.util)

local Collection = {}
Collection.__index = Collection

function Collection.new(matcher)
	if
		#matcher.required == 1
		and #matcher.update == 0
		and #matcher.forbidden == 0
		and #matcher.optional == 0
	then
		return SingleCollection.new(unpack(matcher.required))
	end

	local collectionPool = Pool.new()

	local self = setmetatable({
		added = collectionPool.added,
		removed = collectionPool.removed,

		_pool = collectionPool,
		_updates = {},
		_connections = {},

		_allUpdates = bit32.rshift(0xFFFFFFFF, 32 - #matcher.update),
		_numPacked = #matcher.required + #matcher.update + #matcher.optional,
		_numRequired = #matcher.required,
		_numUpdated = #matcher.update,

		_packed = table.create(
			#matcher.required + #matcher.update + #matcher.optional
		),
		_required = matcher.required,
		_forbidden = matcher.forbidden,
		_updated = matcher.update,
		_optional = matcher.optional,

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
	local packed = self._packed
	local numPacked = self._numPacked

	if next(self._updated) then
		local updates = self._updates
		local pool = self._pool

		for i = self._pool.size, 1, -1 do
			local entity = dense[i]

			self:_pack(entity)
			callback(entity, unpack(packed, 1, numPacked))

			if pool:getIndex(entity) then
				pool:delete(entity)
			end

			updates[entity] = nil
		end
	else
		for i = self._pool.size, 1, -1 do
			local entity = dense[i]

			self:_pack(entity)
			callback(entity, unpack(packed, 1, numPacked))
		end
	end
end

--[[
	Attaches a callback to the collection's added signal that should return a
	list of temporary Instances and/or RBXScriptConnections. Disconnects the
	connections and/or destroys the instances after an entity leaves the
	collection.
]]
Collection.attach = Attachments.attach

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

	if (self._updates[entity] or 0) ~= self._allUpdates then
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

	for i, pool in ipairs(self._updated) do
		local component = pool:get(entity)

		if not component then
			return false
		end

		packed[self._numRequired + i] = component
	end

	for i, pool in ipairs(self._optional) do
		packed[self._numRequired + self._numUpdated + i] = pool:get(entity)
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
		self._updates[entity] = bit32.bor(mask, self._updates[entity] or 0)

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
		local currentUpdates = self._updates[entity]

		if currentUpdates then
			local newUpdates = bit32.band(currentUpdates, mask)

			if newUpdates == 0 then
				self._updates[entity] = nil
			else
				self._updates[entity] = newUpdates
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
