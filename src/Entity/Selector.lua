local Constants = require(script.Parent.Parent.Core.Constants)
local Pool = require(script.Parent.Parent.Core.Pool)
local SingleSelector = require(script.Parent.SingleSelector)

local NONE = Constants.NONE

local Selector = {}
Selector.__index = Selector

function Selector.new(registry, components)
	local required = components.required
	local forbidden = components.forbidden
	local updated = components.updated

	local numRequired = required and #required or 0
	local numUpdated = updated and #updated or 0

	if not updated and not forbidden and numRequired == 1 then
		return SingleSelector.new(registry._pools[required[1]])
	end

	local self = setmetatable({
		_registry = registry,
		_pool = Pool.new(),

		_required = required and registry:getPools(unpack(required)) or NONE,
		_forbidden = forbidden and registry:getPools(unpack(forbidden)) or NONE,
		_updated = updated and registry:getPools(unpack(updated)) or NONE,

		_numRequired = numRequired,
		_numUpdated = numUpdated,

		_packed = table.create(numRequired + numUpdated),
		_updatesPerEntity = updated and {} or NONE,
	}, Selector)

	return self
end

--[[
	Applies the given callback to every tracked entity. For selectors tracking component
	updates, drops all currently tracked entities from the selector.
]]
function Selector:entities(callback)
	local pool = self._pool
	local dense = pool.dense

	if self._updated ~= NONE then
		-- The selector is tracking updates. We don't want to process an update twice,
		-- so we clear the selector's pool.
		local sparse = pool.sparse
		local updatedEntities = self._updatesPerEntity

		for i = pool.size, 1, -1 do
			local entity = dense[i]

			callback(entity)

			updatedEntities[entity] = nil
			sparse[entity] = nil
			dense[i] = nil
		end
	else
		-- The selector is not tracking updates, so we only have to pass each entity in
		-- the pool.
		for i = pool.size, 1, -1 do
			callback(dense[i])
		end
	end
end

--[[
	Same as entities, but also passes required and updated components to the callback.
]]
function Selector:each(callback)
	local dense = self._pool.dense

	if self._updated ~= NONE then
		local updatedEntities = self._updatesPerEntity
		local sparse = self._pool.sparse

		for i = self._pool.size, 1, -1 do
			local entity = dense[i]

			dense[i] = nil
			sparse[i] = nil
			updatedEntities[entity] = nil

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
	Calls the provided callback whenever the selector starts tracking an entity.
]]
function Selector:onAdded(callback)
	return self._pool.onAdd:connect(callback)
end

--[[
	Calls the provided callback whenever the selector stops tracking an entity.
]]
function Selector:onRemoved(callback)
	return self._pool.onRemove:connect(callback)
end

function Selector:connect()
	local connections = {}

	for _, pool in ipairs(self._required) do
		table.insert(connections, pool.onAdd:connect(self:_tryAdd()))
		table.insert(connections, pool.onRemove:connect(self:_tryRemove()))
	end

	for _, pool in ipairs(self._updated) do
		table.insert(connections, pool.onUpdate:connect(self:_tryAddUpdated()))
		table.insert(connections, pool.onRemove:connect(self:_tryRemoveUpdated()))
	end

	for _, pool in ipairs(self._forbidden) do
		table.insert(connections, pool.onAdd:connect(self:_tryRemove()))
		table.insert(connections, pool.onRemove:connect(self:_tryAdd()))
	end

	return function()
		for _, disconnect in ipairs(connections) do
			disconnect()
		end
	end
end

--[[
	Returns the required component pool with the least number of elements.
]]
function Selector:_getShortestRequiredPool()
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
function Selector:_pack(entity)
	for i, pool in ipairs(self._required) do
		self._packed[i] = pool:get(entity)
	end

	local numRequired = self._numRequired

	for i, pool in ipairs(self._updated) do
		self._packed[i + numRequired] = pool:get(entity)
	end
end

--[[
	Returns true if the entity satisfies the selector's required, forbidden, and updated
	component predicates. Otherwise, returns false.
]]
function Selector:_try(entity)
	if (self._updatesPerEntity[entity] or 0) ~= self._numUpdated then
		return false
	end

	for _, pool in ipairs(self._forbidden) do
		if pool:contains(entity) then
			return false
		end
	end

	for _, pool in ipairs(self._required) do
		if not pool:contains(entity) then
			return false
		end
	end

	return true
end

--[[
	Returns true and fills the selector's _packed field with entity's required and
	updated component data if the entity fully satisfies the required, forbidden and
	updated predicates. Otherwise, returns false.
]]
function Selector:_tryPack(entity)
	if (self._updatesPerEntity[entity] or 0) ~= self._numUpdated then
		return false
	end

	for _, pool in ipairs(self._forbidden) do
		if pool:contains(entity) then
			return false
		end
	end

	for i, pool in ipairs(self._required) do
		local denseIndex = pool:contains(entity)

		if not denseIndex then
			return false
		end

		self._packed[i] = pool.objects[denseIndex]
	end

	local numRequired = self._numRequired

	for i, pool in ipairs(self._updated) do
		local denseIndex = pool:contains(entity)

		if not denseIndex then
			return false
		end

		self._packed[numRequired + i] = pool.objects[denseIndex]
	end

	return true
end

function Selector:_tryAdd()
	return function(entity)
		if not self._pool:contains(entity) and self:_tryPack(entity) then
			self._pool:insert(entity)
			self._pool.onAdd:dispatch(entity, unpack(self._packed))
		end
	end
end

function Selector:_tryAddUpdated()
	return function(entity)
		self._updatesPerEntity[entity] = (self._updatesPerEntity[entity] or 0) + 1

		if not self._pool:contains(entity) and self:_tryPack(entity) then
			self._pool:insert(entity)
			self._pool.onAdd:dispatch(entity, unpack(self._packed))
		end
	end
end

function Selector:_tryRemove()
	return function(entity)
		if self._pool:contains(entity) then
			self:_pack(entity)
			self._pool.onRemove:dispatch(entity, unpack(self._packed))
			self._pool:delete(entity)
		end
	end
end

function Selector:_tryRemoveUpdated()
	return function(entity)
		local numUpdatesOnEntity = self._updatesPerEntity[entity]

		if numUpdatesOnEntity then
			local newNumUpdated = numUpdatesOnEntity - 1

			if newNumUpdated == 0 then
				self._updatesPerEntity[entity] = nil
			else
				self._updatesPerEntity[entity] = newNumUpdated
			end
		end

		if self._pool:contains(entity) then
			self:_pack(entity)
			self._pool.onRemove:dispatch(entity, unpack(self._packed))
			self._pool:delete(entity)
		end
	end
end

return Selector
