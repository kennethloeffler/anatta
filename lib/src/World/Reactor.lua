--[=[
	@class Reactor
	Provides scoped access to the contents of a [`Registry`](/api/World#Registry)
	according to a [`Query`](/api/World#Query).

	A `Reactor` is stateful and observes a [`World`'s registry](/api/World#registry). When
	an entity matches the [`Query`](/api/World#Query), the entity enters the `Reactor` and
	remains present until the entity fails to match the [`Query`](/api/World#Query).

	Unlike a [`Mapper`](/api/Mapper), a `Reactor` has the ability to track updates to
	components. When a component in [`Query.withUpdated`](/api/World#Query) is replaced
	using [`Registry:replaceComponent`](/api/Registry#replaceComponent) or
	[`Mapper:map`](/api/Mapper#map), the `Reactor` "sees" the replacement and considers
	the component updated. Updated components can then be "consumed" using
	[`Reactor:consumeEach`](#consumeEach) or [`Reactor:consume`](#consume).

	Also unlike a [`Mapper`](/api/Mapper), a `Reactor` has the ability to "attach"
	`RBXScriptConnection`s and `Instance`s to entities present in the `Reactor` using
	[`Reactor:withAttachments`](#withAttachments).

	You can create a `Reactor` using [`World:getReactor`](/api/World#getReactor).
]=]

local Finalizers = require(script.Parent.Parent.Core.Finalizers)
local Pool = require(script.Parent.Parent.Core.Pool)
local SingleReactor = require(script.Parent.SingleReactor)
local Types = require(script.Parent.Parent.Types)

local util = require(script.Parent.Parent.util)

local ErrEntityMissing = "entity %d is not present in this reactor"

local WarnNoAttachmentsTable = "withAttachments callback defined in %s at line %s did not return a table"

local Reactor = {}
Reactor.__index = Reactor

--[=[
	@param registry Registry
	@param query Query
	@private

	Creates a new `Reactor` given a [`Query`](/api/Anatta#Query).
]=]
function Reactor.new(registry, query)
	util.jumpAssert(Types.Query(query))

	local withAll = query.withAll or {}
	local withUpdated = query.withUpdated or {}
	local without = query.without or {}
	local withAny = query.withAny or {}

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
	@param callback (entity: number, ...any) -> {RBXScriptConnection | Instance | (...) -> ()}

	Calls the callback every time an entity enters the `Reactor`, passing each entity and
	its components and attaching the return value to each entity.  The callback should
	return a list of connections, `Instance`s, and/or functions. When the entity later
	leaves the `Reactor`, attached connections are disconnected, attached `Instance`s are
	destroyed, and attached functions are called.

	:::warning
	Yielding inside of the callback is forbidden. There are currently no protections
	against this, so be careful!
	:::
]=]
function Reactor:withAttachments(callback)
	local entityAdded = self.added:connect(function(entity, ...)
		local attachments = callback(entity, ...)

		if typeof(attachments) ~= "table" then
			warn(WarnNoAttachmentsTable:format(debug.info(callback, "s"), debug.info(callback, "l")))
			attachments = {}
		end

		local index = self._pool:getIndex(entity)

		if not index then
			-- Another added listener or the withAttachments callback caused the entity to leave
			-- the Reactor. This is pretty weird thing for a consumer of this function to
			-- do, but we shouldn't throw or leak attachments.
			for _, item in pairs(attachments) do
				Finalizers[typeof(item)](item)
			end

			return
		else
			self._pool.components[index] = attachments
		end
	end)

	local entityRemoved = self.removed:connect(function(entity)
		local attachments = self._pool:get(entity)

		if attachments == nil then
			-- Tried to double remove (removeComponent on a withAll component inside the callback)? Don't really care...
			return
		end

		for _, item in pairs(attachments) do
			Finalizers[typeof(item)](item)
		end
	end)

	table.insert(self._connections, entityAdded)
	table.insert(self._connections, entityRemoved)
end

function Reactor:getAttachment(entity)
	util.jumpAssert(self._pool:getIndex(entity) ~= nil, ErrEntityMissing, entity)
	return self._pool:get(entity)
end

--[=[
	@param callback (entity: number, ...any) -> ()

	Iterates over the all the entities present in the `Reactor`. Calls the callback for
	each entity, passing each entity followed by the components named in the
	[`Query`](/api/World#Query).

	:::info
	It's safe to add or remove components inside of the callback.
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

function Reactor:find(callback)
	local dense = self._pool.dense
	local packed = self._packed
	local numPacked = self._numPacked

	for i = self._pool.size, 1, -1 do
		local entity = dense[i]

		self:_pack(entity)

		local result = callback(entity, unpack(packed, 1, numPacked))

		if result ~= nil then
			return result
		end
	end

	return nil
end

function Reactor:filter(callback)
	local results = {}
	local dense = self._pool.dense
	local packed = self._packed
	local numPacked = self._numPacked

	for i = self._pool.size, 1, -1 do
		local entity = dense[i]

		self:_pack(entity)
		local result = callback(entity, unpack(packed, 1, numPacked))

		if result ~= nil then
			table.insert(results, result)
		end
	end

	return results
end

--[=[
	@param callback (entity: number, ...any) -> ()

	Iterates over all the entities present in the `Reactor` and clears each entity's
	update status. Calls the callback for each entity visited during the iteration,
	passing the entity followed by the components named in the
	[`Query`](/api/World#Query).

	This function effectively "consumes" all updates made to components named in
	[`Query.withUpdated`](/api/World#Query), emptying the `Reactor`. A consumer that wants
	to selectively consume updates should use [`consume`](#consume) instead.

	:::info
	It's safe to add or remove components inside of the callback.
]=]
function Reactor:consumeEach(callback)
	local dense = self._pool.dense
	local packed = self._packed
	local numPacked = self._numPacked

	local updates = self._updates
	local pool = self._pool

	for i = self._pool.size, 1, -1 do
		local entity = dense[i]

		updates[entity] = nil
		self:_pack(entity)
		callback(entity, unpack(packed, 1, numPacked))

		if pool:getIndex(entity) then
			pool:delete(entity)
		end
	end
end

--[=[
	Consumes updates made to components named in `Query.withUpdated`.

	@error "entity %d is not present in this reactor" -- The reactor doesn't contain that entity.

	@param entity number
]=]
function Reactor:consume(entity)
	util.jumpAssert(self._pool:getIndex(entity) ~= nil, ErrEntityMissing, entity)

	self._updates[entity] = nil
	self:_pack(entity)
	self.removed:dispatch(entity, unpack(self._packed, 1, self._numPacked))

	if self._pool:getIndex(entity) then
		self._pool:delete(entity)
	end
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

			if self._pool:getIndex(entity) then
				self._pool:delete(entity)
			end
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

			if self._pool:getIndex(entity) then
				self._pool:delete(entity)
			end
		end
	end
end

return Reactor
