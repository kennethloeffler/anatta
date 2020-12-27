local Constants = require(script.Parent.Parent.Core.Constants)
local Pool = require(script.Parent.Parent.Core.Pool)
local SingleCollection = require(script.Parent.SingleCollection)

local NONE = Constants.NONE

local Collection = {}
Collection.__index = Collection

function Collection.new(registry, components)
	local required = registry:getPools(unpack(components.required or NONE))
	local forbidden = registry:getPools(unpack(components.forbidden or NONE))
	local updated = registry:getPools(unpack(components.updated or NONE))

	assert(
		next(required) or next(updated),
		"Collections must be given at least one required or updated component"
	)
	assert(#updated <= 32, "Collections may only track up to 32 updated components")

	if not next(updated) and not next(forbidden) and #required == 1 then
		-- The selector is tracking entities with just one required component. This is a
		-- case we should optimize for. It does not require any additional state and
		-- only amounts to iterating over one Pool's list(s) and connecting to one set
		-- of signals.
		return SingleCollection.new(registry._pools[required[1]])
	end

	local self = setmetatable({
		_pool = Pool.new(),
		_updatedSet = {},
		_connections = table.create(2 * (#required + #updated + #forbidden)),
		_packed = table.create(#required + #updated),

		_required = required,
		_forbidden = forbidden,
		_updated = updated,

		_numRequired = #required,
		_numUpdated = #updated,
		_allUpdatedSet = bit32.rshift(0xFFFFFFFF, 32 - #updated),
	}, Collection)

	local connections = self._connections

	for _, pool in ipairs(required) do
		table.insert(connections, pool.onAdd:connect(self:_tryAdd()))
		table.insert(connections, pool.onRemove:connect(self:_tryRemove()))
	end

	for i, pool in ipairs(updated) do
		table.insert(connections, pool.onUpdate:connect(self:_tryAddUpdated(i - 1)))
		table.insert(connections, pool.onRemove:connect(self:_tryRemoveUpdated(i - 1)))
	end

	for _, pool in ipairs(forbidden) do
		table.insert(connections, pool.onAdd:connect(self:_tryRemove()))
		table.insert(connections, pool.onRemove:connect(self:_tryAdd()))
	end

	return self
end

--[[
	Applies the callback to each tracked entity and its components. Passes the entity
	first, followed by its required components and updated components in the same order
	they were given to the selector.
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
	Applies the callback to an entity and component(s) just after the selector begins
	tracking it.
]]
function Collection:onAdded(callback)
	return self._pool.onAdd:connect(callback)
end

--[[
	Applies the callback to an entity and component(s) just before the selector stops
	tracking it.
]]
function Collection:onRemoved(callback)
	return self._pool.onRemove:connect(callback)
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
	Unconditionally fills the selector's _packed field with the entity's required and
	updated component data.
]]
function Collection:_pack(entity)
	for i, pool in ipairs(self._required) do
		self._packed[i] = pool:get(entity)
	end

	local numRequired = self._numRequired

	for i, pool in ipairs(self._updated) do
		self._packed[i + numRequired] = pool:get(entity)
	end
end

--[[
	Returns true and fills the selector's _packed field with entity's required and
	updated component data if the entity fully satisfies the required, forbidden and
	updated predicates. Otherwise, returns false.
]]
function Collection:_tryPack(entity)
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

		self._packed[i] = pool.objects[denseIndex]
	end

	local numRequired = self._numRequired

	for i, pool in ipairs(self._updated) do
		local denseIndex = pool:getIndex(entity)

		if not denseIndex then
			return false
		end

		self._packed[numRequired + i] = pool.objects[denseIndex]
	end

	return true
end

function Collection:_tryAdd()
	return function(entity)
		if not self._pool:getIndex(entity) and self:_tryPack(entity) then
			self._pool:insert(entity)
			self._pool.onAdd:dispatch(entity, unpack(self._packed))
		end
	end
end

function Collection:_tryAddUpdated(offset)
	local mask = bit32.lshift(1, offset)

	return function(entity)
		self._updatedSet[entity] = bit32.bor(mask, self._updatedSet[entity] or 0)

		if not self._pool:getIndex(entity) and self:_tryPack(entity) then
			self._pool:insert(entity)
			self._pool.onAdd:dispatch(entity, unpack(self._packed))
		end
	end
end

function Collection:_tryRemove()
	return function(entity)
		if self._pool:getIndex(entity) then
			self:_pack(entity)
			self._pool.onRemove:dispatch(entity, unpack(self._packed))
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
			self._pool.onRemove:dispatch(entity, unpack(self._packed))
			self._pool:delete(entity)
		end
	end
end

return Collection
