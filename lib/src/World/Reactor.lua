--[=[
	@class Reactor
	Provides scoped access to the contents of a [`Registry`](Registry) according to a
	[`Query`](Anatta#Query).

	A `Reactor` is stateful. In contrast to a [`Mapper`](Mapper), a `Reactor` can track
	updates to components with [`Query.withUpdated`](Query#withUpdated).
]=]

local Finalizers = require(script.Parent.Parent.Core.Finalizers)
local Pool = require(script.Parent.Parent.Core.Pool)
local SingleReactor = require(script.Parent.SingleReactor)
local Types = require(script.Parent.Parent.Types)

local util = require(script.Parent.Parent.util)

local ErrNeedComponents = "Reactors need at least one required, updated, or optional component type"
local ErrTooManyUpdated = "Reactors can only track up to 32 updated component types"

local Reactor = {}
Reactor.__index = Reactor

--[=[
	@param registry Registry
	@param query Query
	@private

	Creates a new `Reactor` given a [`Query`](Anatta#Query).
]=]
function Reactor.new(registry, query)
	util.jumpAssert(Types.Query(query))

	local withAll = query.withAll or {}
	local withUpdated = query.withUpdated or {}
	local without = query.without or {}
	local withAny = query.withAny or {}

	util.jumpAssert(#withUpdated <= 32, ErrTooManyUpdated)
	util.jumpAssert(#withAll > 0 or #withUpdated > 0 or #withAny > 0, ErrNeedComponents)

	if #withAll == 1 and #withUpdated == 0 and #without == 0 and #withAny == 0 then
		return SingleReactor.new(registry:getPool(query.withAll[1]))
	end

	local reactorContents = Pool.new({ name = "reactorInternal", type = {} })

	local self = setmetatable({
		added = reactorContents.added,
		removed = reactorContents.removed,

		_pool = reactorContents,
		_updates = {},
		_connections = {},

		_allUpdates = bit32.rshift(0xFFFFFFFF, 32 - #withUpdated),
		_numPacked = #withAll + #withUpdated + #withAny,
		_numRequired = #withAll,
		_numUpdated = #withUpdated,

		_packed = table.create(#withAll + #withUpdated + #withAny),
		_required = registry:getPools(withAll),
		_forbidden = registry:getPools(without),
		_updated = registry:getPools(withUpdated),
		_optional = registry:getPools(withAny),
	}, Reactor)

	for _, pool in ipairs(self._required) do
		table.insert(self._connections, pool.added:connect(self:_tryAdd()))
		table.insert(self._connections, pool.removed:connect(self:_tryRemove()))
	end

	for i, pool in ipairs(self._updated) do
		table.insert(self._connections, pool.updated:connect(self:_tryAddUpdated(i - 1)))
		table.insert(self._connections, pool.removed:connect(self:_tryRemoveUpdated(i - 1)))
	end

	for _, pool in ipairs(self._forbidden) do
		table.insert(self._connections, pool.added:connect(self:_tryRemove()))
		table.insert(self._connections, pool.removed:connect(self:_tryAdd()))
	end

	for _, pool in ipairs(self._optional) do
		table.insert(self._connections, pool.added:connect(self:_tryAdd()))
	end

	return self
end

--[=[
	@param callback (number, ...any) -> {RBXScriptConnection | Instance}

	Calls the callback every time an entity enters the `Reactor`, passing each entity and
	its components and attaching the return value to each entity.  The callback should
	return a list of connections and/or `Instance`s. When the entity later leaves the
	`Reactor`, attached `Instance`s are destroyed and attached connections are
	disconnected.
]=]
function Reactor:withAttachments(callback)
	local attachmentsAdded = self.added:connect(function(entity, ...)
		self._pool:replace(entity, callback(entity, ...))
	end)

	local attachmentsRemoved = self.removed:connect(function(entity)
		for _, item in ipairs(self._pool:get(entity)) do
			Finalizers[typeof(item)](item)
		end
	end)

	table.insert(self._connections, attachmentsAdded)
	table.insert(self._connections, attachmentsRemoved)
end

--[=[
	@private

	Detaches all the attachments made to this `Reactor`, destroying all attached
	`Instance`s and disconnecting all attached connections.
]=]
function Reactor:detach()
	for _, attached in ipairs(self._pool.components) do
		for _, item in ipairs(attached) do
			Finalizers[typeof(item)](item)
		end
	end

	for _, connection in ipairs(self._connections) do
		connection:disconnect()
	end
end

--[=[
	@param callback (number, ...any)

	Iterates over the all the entities present in the `Reactor`. Calls the callback for
	each entity, passing each entity followed by the components specified by the `Query`.
]=]
function Reactor:each(callback)
	local dense = self._pool.dense
	local packed = self._packed
	local numPacked = self._numPacked

	for i = self._pool.size, 1, -1 do
		local entity = dense[i]

		self:_pack(entity)
		callback(entity, unpack(packed, 1, numPacked))
	end
end

--[=[
	@param callback (number, ...any)

	Iterates over all the entities present in the `Reactor` and clears each entity's set
	of updated componants. Calls the callback for each entity, passing each entity followed
	by the components specified by the `Query`.
]=]
function Reactor:consumeEach(callback)
	local dense = self._pool.dense
	local packed = self._packed
	local numPacked = self._numPacked

	local updates = self._updates
	local pool = self._pool

	for i = self._pool.size, 1, -1 do
		local entity = dense[i]

		pool:delete(entity)
		updates[entity] = nil
		self:_pack(entity)
		callback(entity, unpack(packed, 1, numPacked))
	end
end

--[=[
	@param entity number

	Clears a given entity's set of updated components.
]=]
function Reactor:consume(entity)
	self._pool:delete(entity)
	self._updates[entity] = nil
end

--[[
	Unconditionally fills the collection's _packed field with the entity's required,
	updated, and optional components.
]]
function Reactor:_pack(entity)
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
function Reactor:_tryPack(entity)
	local packed = self._packed
	local numRequired = self._numRequired
	local numUpdated = self._numUpdated

	if (self._updates[entity] or 0) ~= self._allUpdates then
		return false
	end

	for _, pool in ipairs(self._forbidden) do
		if pool:getIndex(entity) then
			return false
		end
	end

	for i, pool in ipairs(self._required) do
		local index = pool:getIndex(entity)

		if not index then
			return false
		end

		packed[i] = pool.components[index]
	end

	for i, pool in ipairs(self._updated) do
		local index = pool:getIndex(entity)

		if not index then
			return false
		end

		packed[numRequired + i] = pool.components[index]
	end

	for i, pool in ipairs(self._optional) do
		packed[numRequired + numUpdated + i] = pool:get(entity)
	end

	return true
end

function Reactor:_tryAdd()
	return function(entity)
		if not self._pool:getIndex(entity) and self:_tryPack(entity) then
			self._pool:insert(entity)
			self._pool.added:dispatch(entity, unpack(self._packed, 1, self._numPacked))
		end
	end
end

function Reactor:_tryAddUpdated(offset)
	local mask = bit32.lshift(1, offset)

	return function(entity)
		self._updates[entity] = bit32.bor(mask, self._updates[entity] or 0)

		if not self._pool:getIndex(entity) and self:_tryPack(entity) then
			self._pool:insert(entity)
			self._pool.added:dispatch(entity, unpack(self._packed, 1, self._numPacked))
		end
	end
end

function Reactor:_tryRemove()
	return function(entity)
		if self._pool:getIndex(entity) then
			self:_pack(entity)
			self._pool.removed:dispatch(entity, unpack(self._packed, 1, self._numPacked))
			self._pool:delete(entity)
		end
	end
end

function Reactor:_tryRemoveUpdated(offset)
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

return Reactor
