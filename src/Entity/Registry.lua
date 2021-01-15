--[[
	Registry.lua
]]
local Constants = require(script.Parent.Parent.Core.Constants)
local Pool = require(script.Parent.Parent.Core.Pool)

local DEBUG = Constants.DEBUG
local ENTITYID_MASK = Constants.ENTITYID_MASK
local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
local NULL_ENTITYID = Constants.NULL_ENTITYID

local ErrBadEntityType = "entity must be a number (got %s)"
local ErrAlreadyHasComponent = "entity %08X already has a %s"
local ErrBadComponentName = "invalid component identifier: %s"
local ErrInvalidEntity = "entity %08X either does not exist or it has been destroyed"
local ErrMissingComponent = "entity %08X does not have a %s"
local ErrComponentNameTaken = "there is already a component named %s"

local WarnEntityAlreadyExists = "creating a new entity because %08X's id is already in use"

local Registry = {}
Registry.__index = Registry

function Registry.new()
	return setmetatable({
		_entities = {},
		_pools = {},
		_nextRecyclable = NULL_ENTITYID,
		_size = 0,
	}, Registry)
end

--[[
	Returns an integer equal to the first ENTITYID_WIDTH bits of the entity.  The
	equality

	registry._entities[id] == entity

	generally holds if the entity is valid.
]]
function Registry.getId(entity)
	return bit32.band(entity, ENTITYID_MASK)
end

--[[
	Returns an integer equal the last (32 - ENTITYID_WIDTH) bits of the entity.
]]
function Registry.getVersion(entity)
	return bit32.rshift(entity, ENTITYID_WIDTH)
end

--[[
	Defines a component for the registry.  If the component's type is an Instance or an
	interface with a top-level field that is an Instance, the registry automatically
	calls Destroy when the component is removed.
]]
function Registry:define(componentName, typeCheck)
	assert(not self._pools[componentName], ErrComponentNameTaken:format(componentName))

	self._pools[componentName] = Pool.new(componentName, typeCheck)
end

--[[
	Returns a new entity.
]]
function Registry:create()
	if self._nextRecyclable == NULL_ENTITYID then
		-- no entityIds to recycle
		local newEntity = self._size + 1
		self._size = newEntity
		self._entities[newEntity] = newEntity

		return newEntity
	else
		-- there is at least one recyclable entityId; pop the free list
		local entities = self._entities
		local nextRecyclable = self._nextRecyclable
		local node = entities[nextRecyclable]
		local recycledEntity = bit32.bor(
			nextRecyclable,
			bit32.lshift(bit32.rshift(node, ENTITYID_WIDTH), ENTITYID_WIDTH)
		)

		entities[nextRecyclable] = recycledEntity
		self._nextRecyclable = bit32.band(node, ENTITYID_MASK)

		return recycledEntity
	end
end

--[[
	Returns a new entity equal to the given entity if and only if the given entity id is
	not in use by the store, otherwise returns a new entity created normally.
]]
function Registry:createFrom(entity)
	local entityId = bit32.band(entity, ENTITYID_MASK)
	local entities = self._entities
	local existingEntityId = bit32.band(
		entities[entityId] or NULL_ENTITYID,
		ENTITYID_MASK
	)

	if existingEntityId == NULL_ENTITYID then
		-- the given identifier's entityId is out of range; create the entities in
		-- between size and entityId and add them to the free list
		local nextRecyclable = self._nextRecyclable

		for id = self._size + 1, entityId - 1  do
			entities[id] = nextRecyclable
			nextRecyclable = id
		end

		self._size = entityId
		self._nextRecyclable = nextRecyclable
		entities[entityId] = entity

		return entity
	elseif existingEntityId == entityId then
		-- the entityId is in use; create a new entity normally
		if DEBUG then
			warn(WarnEntityAlreadyExists:format(entity, entityId))
		end

		return self:create()
	else
		-- the entityId is in the free list; find it and remove it
		local nextRecyclable = self._nextRecyclable

		if nextRecyclable == entityId then
			-- entityId is at the head of the list; don't need to iterate, just need to
			-- pop
			self._nextRecyclable = bit32.band(entities[entityId], ENTITYID_MASK)
			entities[entityId] = entity

			return entity
		end

		local lastRecyclable

		-- find the entityId in the free list
		while nextRecyclable ~= entityId do
			lastRecyclable = nextRecyclable
			nextRecyclable = bit32.band(self._entities[nextRecyclable], ENTITYID_MASK)
		end

		-- make the previous element point to the next
		entities[lastRecyclable] = bit32.bor(
			bit32.band(entities[entityId], ENTITYID_MASK),
			bit32.lshift(bit32.rshift(entities[lastRecyclable], ENTITYID_WIDTH), ENTITYID_WIDTH)
		)

		entities[entityId] = entity

		return entity
	end
end

--[[
	Destroys an entity (and by extension, all of its components) and frees its id.
]]
function Registry:destroy(entity)
	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))
	end

	local entityId = bit32.band(entity, ENTITYID_MASK)

	for _, pool in pairs(self._pools) do
		if pool:getIndex(entity) then
			pool.onRemoved:dispatch(entity, pool:get(entity))
			pool:delete(entity)
		end
	end

	-- push this entityId onto the free list so that it can be recycled, and increment the
	-- identifier's version to avoid possible collision
	self._entities[entityId] = bit32.bor(
		self._nextRecyclable,
		bit32.lshift(bit32.rshift(entity, ENTITYID_WIDTH) + 1, ENTITYID_WIDTH)
	)

	self._nextRecyclable = entityId
end

--[[
	Returns true if the entity identifier corresponds to a valid entity.  Otherwise,
	returns false.
]]
function Registry:valid(entity)
	if DEBUG then
		local ty = type(entity)
		assert(ty == "number", ErrBadEntityType:format(ty))
	end

	return self._entities[bit32.band(entity, ENTITYID_MASK)] == entity
end

--[[
	Returns true if the entity has no assigned components.  Otherwise, returns false.
]]
function Registry:stub(entity)
	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))
	end

	for _, pool in pairs(self._pools) do
		if pool:getIndex(entity) then
			return false
		end
	end

	return true
end

--[[
	Passes all the component type names in use to the given function.

	If an entity is given, passes only the names for which the entity has a component.
]]
function Registry:visit(func, entity)
	if entity ~= nil then
		if DEBUG then
			assert(self:valid(entity), ErrInvalidEntity:format(entity))
		end

		for component, pool in pairs(self._pools) do
			if pool:getIndex(entity) then
				func(component)
			end
		end
	else
		for component in pairs(self._pools) do
			func(component)
		end
	end
end

--[[
	Returns true if the entity has a component of all of the given types.  Otherwise,
	returns false.
]]
function Registry:has(entity, ...)
	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))

		for i = 1, select("#", ...) do
			assert(self._pools[select(i, ...)], ErrBadComponentName:format(select(i, ...)))
		end
	end

	for i = 1, select("#", ...) do
		if not self._pools[select(i, ...)]:getIndex(entity) then
			return false
		end
	end

	return true
end

--[[
	Returns true if the entity has a component of any of the given types.  Otherwise,
	returns false.
]]
function Registry:any(entity, ...)
	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))

		for i = 1, select("#", ...) do
			assert(self._pools[select(i, ...)], ErrBadComponentName:format(select(i, ...)))
		end
	end

	for i = 1, select("#", ...) do
		if self._pools[select(i, ...)]:getIndex(entity) then
			return true
		end
	end

	return false
end

--[[
	Returns the component of the given type on the entity.

	Throws if the entity does not have the component.
]]
function Registry:get(entity, name)
	local pool = self._pools[name]

	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))
		assert(pool, ErrBadComponentName:format(name))
		assert(pool:getIndex(entity), ErrMissingComponent:format(entity, name))
	end

	return self._pools[name]:get(entity)
end

--[[
	If the entity has the component, returns the component.  Otherwise, does nothing.
]]
function Registry:tryGet(entity, name)
	local pool = self._pools[name]

	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))

	end

	if pool:getIndex(entity) then
		return pool:get(entity)
	end
end

--[[
	Returns all components of the given types on the entity.
]]
function Registry:multiGet(entity, output, ...)
	for i = 1, select("#", ...) do
		output[i] = self:get(entity, select(i, ...))
	end

	return unpack(output)
end

--[[
	Adds the component to the entity and returns the component.

	An entity may only have one component of each type at a time. Throws
	upon an attempt to add multiple components of the same type to an entity.
]]
function Registry:add(entity, name, object)
	local pool = self._pools[name]

	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))
		assert(pool, ErrBadComponentName:format(name))
		assert(not pool:getIndex(entity), ErrAlreadyHasComponent:format(entity, name))
		assert(pool.typeCheck(object))
	end

	pool:insert(entity, object)
	pool.onAdded:dispatch(entity, object)

	return object
end

--[[
	If the entity does not have the component, adds and returns the component.
	Otherwise, does nothing.
]]
function Registry:tryAdd(entity, name, object)
	local pool = self._pools[name]

	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))
		assert(pool, ErrBadComponentName:format(name))
		assert(pool.typeCheck(object))
	end

	if pool:getIndex(entity) then
		return
	end

	pool:insert(entity, object)
	pool.onAdded:dispatch(entity, object)

	return object
end

--[[
	Adds the given components to the entity and returns the entity.
]]
function Registry:multiAdd(entity, ...)
	local num = select("#", ...)

	for i = 1, num, 2 do
		self:add(entity, select(i, ...), select(i + 1, ...))
	end

	return entity
end

--[[
	If the entity has the component, returns the component.  Otherwise adds the
	component to the entity and returns the component.
]]
function Registry:getOrAdd(entity, name, object)
	local pool = self._pools[name]

	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))
		assert(pool, ErrBadComponentName:format(name))
		assert(pool.typeCheck(object))
	end

	local denseIndex = pool:getIndex(entity)

	if denseIndex then
		return pool.objects[denseIndex]
	else
		pool:insert(entity, object)
		pool.onAdded:dispatch(entity, object)

		return object
	end
end

--[[
	Replaces the component on the entity with the given component.

	Throws upon an attempt to replace a component that the entity does not have.
]]
function Registry:replace(entity, name, object)
	local pool = self._pools[name]

	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))
		assert(pool, ErrBadComponentName:format(name))
		assert(pool.typeCheck(object))
		assert(pool:getIndex(entity), ErrMissingComponent:format(entity, name))
	end

	pool.onUpdated:dispatch(entity, object)
	pool:replace(entity, object)

	return object
end

--[[
	If the entity has the component, replaces it with the given component and returns the
	new component.  Otherwise, adds the component to the entity and returns the new
	component.
]]
function Registry:addOrReplace(entity, name, object)
	local pool = self._pools[name]

	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))
		assert(pool, ErrBadComponentName:format(name))
		assert(pool.typeCheck(object))
	end

	local denseIndex = pool:getIndex(entity)

	if denseIndex then
		pool.onUpdated:dispatch(entity, object)
		pool.objects[denseIndex] = object

		return object
	end

	pool:insert(entity, object)
	pool.onAdded:dispatch(entity, object)

	return object
end

--[[
	Removes the component from the entity.

	Throws upon an attempt to remove a component which the entity does not
	have.
]]
function Registry:remove(entity, name)
	local pool = self._pools[name]

	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))
		assert(pool, ErrBadComponentName:format(name))
		assert(pool:getIndex(entity), ErrMissingComponent:format(entity, name))
	end

	pool.onRemoved:dispatch(entity, pool:get(entity))
	pool:delete(entity)
end

--[[
	Removes all of the given components from the entity.
]]
function Registry:multiRemove(entity, ...)
	for i = 1, select("#", ...) do
		self:remove(entity, select(i, ...))
	end
end

--[[
	If the entity has the component, removes it.  Otherwise, does nothing.
]]
function Registry:tryRemove(entity, name)
	local pool = self._pools[name]

	if DEBUG then
		assert(self:valid(entity), ErrInvalidEntity:format(entity))
		assert(pool, ErrBadComponentName:format(name))
	end

	if pool:getIndex(entity) then
		pool.onRemoved:dispatch(entity, pool:get(entity))
		pool:delete(entity)

		return true
	end

	return false
end


--[[
	Returns the number of entities currently in use.
]]
function Registry:numEntities()
	local curr = self._nextRecyclable
	local num = self._size

	while curr ~= NULL_ENTITYID do
		num -= 1
		curr = bit32.band(self._entities[curr], ENTITYID_MASK)
	end

	return num
end

--[[
	Pases each entity currently in use to the given function.
]]
function Registry:each(func)
	if self._nextRecyclable == NULL_ENTITYID then
		for _, entity in ipairs(self._entities) do
			func(entity)
		end
	else
		for id, entity in ipairs(self._entities) do
			if bit32.band(entity, ENTITYID_MASK) == id then
				func(entity)
			end
		end
	end
end

--[[
	Returns a list of entities and a list of components, both sorted the same way.
]]
function Registry:raw(name)
	local pool = self._pools[name]

	if DEBUG then
		assert(pool, ErrBadComponentName:format(name))
	end

	return pool.dense, pool.objects
end

--[[
	Returns the number of entities with the specified component.
]]
function Registry:count(name)
	local pool = self._pools[name]

	if DEBUG then
		assert(pool, ErrBadComponentName:format(name))
	end

	return pool.size
end

--[[
	Returns a list of pools used to manage the specified components in the same order as
	the given tuple.
]]
function Registry:getPools(...)
	local n = select("#", ...)
	local output = table.create(n)

	for i = 1, n do
		local name = select(i, ...)
		local pool = self._pools[name]

		if DEBUG then
			assert(pool, ErrBadComponentName:format(name))
		end

		output[i] = pool
	end

	return output
end

return Registry
