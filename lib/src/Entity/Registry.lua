--[[
	Registry.lua
]]
local Constants = require(script.Parent.Parent.Core.Constants)
local Dom = require(script.Parent.Parent.Dom)
local Pool = require(script.Parent.Parent.Core.Pool)
local util = require(script.Parent.Parent.util)

local jumpAssert = util.jumpAssert

local DEBUG = Constants.Debug
local ENTITYID_MASK = Constants.EntityIdMask
local ENTITYID_WIDTH = Constants.EntityIdWidth
local NULL_ENTITYID = Constants.NullEntityId

local ErrBadEntityType = "entity must be a number (got %s)"
local ErrAlreadyHasComponent = "entity %s already has a %s"
local ErrBadComponentName = "invalid component identifier: %s"
local ErrInvalidEntity = "entity %s either does not exist or it has been destroyed"
local ErrMissingComponent = "entity %s does not have a %s"
local ErrComponentNameTaken = "there is already a component named %s"

local WarnEntityAlreadyExists = "creating a new entity (%08X) because %08X's id is already in use"

local Registry = {}
Registry.__index = Registry

function Registry.new(components)
	local pools = {}

	for componentName, typeDefinition in pairs(components) do
		pools[componentName] = Pool.new(componentName, typeDefinition)
	end

	return setmetatable({
		_entities = {},
		_pools = pools,
		_nextRecyclableEntityId = NULL_ENTITYID,
		_size = 0,
	}, Registry)
end

function Registry:tryFromDom()
	jumpAssert(self._size == 0, "Registry was not empty")

	local entitySet = {}

	for componentName, pool in pairs(self._pools) do
		if componentName:sub(1, 1) == "." then
			continue
		end

		local success, result = Dom.tryFromTag(pool, componentName, pool.typeDefinition)

		if success then
			for _, entity in ipairs(pool.dense) do
				entitySet[entity] = true
			end
		else
			return false, result
		end
	end

	-- There is a bit of trickery going on here. A simple traversal over entitySet,
	-- calling createFrom on each entity, does work - but it is unordered. If createFrom
	-- is given an entity that is out of range, it must backfill _entities with recyclable
	-- IDs. When entities with the same ID are later encountered at some point later in
	-- the iteration, createFrom must search the recyclable list. It likely contains many
	-- elements in such a scenario, so this can become fairly costly overall.

	-- To get around this, we create an intermediate list of entities and sort it by its
	-- entity ID field. This results in an ordering identical to the eventual registry. In
	-- this scenario, createFrom backfills less often and the recyclable list is kept
	-- smaller.
	local entities = {}

	for entity in pairs(entitySet) do
		table.insert(entities, entity)
	end

	table.sort(entities, function(lhs, rhs)
		return bit32.band(lhs, ENTITYID_MASK) < bit32.band(rhs, ENTITYID_MASK)
	end)

	for _, entity in ipairs(entities) do
		self:createFrom(entity)
	end

	for _, pool in pairs(self._pools) do
		for _, entity in ipairs(pool.dense) do
			pool.added:dispatch(entity, pool:get(entity))
		end
	end

	return true
end

--[[
	Returns an integer equal to the first ENTITYID_WIDTH bits of the entity. The equality

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

function Registry:load(registry)
	jumpAssert(self._size == 0)

	self._size = registry._size
	self._entities = registry._entities
	self._nextRecyclableEntityId = registry._nextRecyclableEntityId

	for _, otherPool in pairs(registry._pools) do
		local componentName = otherPool.name

		if not self:hasDefined(componentName) then
			continue
		end

		local pool = self:getPool(componentName)
		local checkSuccess, checkErr, failedEntity = true, "", 0

		for i, component in ipairs(otherPool.components) do
			local entity = otherPool.dense[i]
			local success, err = pool.typeCheck(component)

			if not success then
				checkSuccess, checkErr, failedEntity = false, err, entity
				break
			end
		end

		if checkSuccess then
			pool.size = otherPool.size
			pool.sparse = otherPool.sparse
			pool.dense = otherPool.dense
			pool.components = otherPool.components

			for _, entity in ipairs(pool.dense) do
				pool.added:dispatch(entity, pool:get(entity))
			end
		else
			warn(("Type check for entity %s's %s failed: %s"):format(
				failedEntity,
				componentName,
				checkErr
			))
			continue
		end
	end
end

--[[
	Defines a component for the registry.
]]
function Registry:define(componentName, typeDefinition)
	jumpAssert(not self._pools[componentName], ErrComponentNameTaken:format(componentName))

	self._pools[componentName] = Pool.new(componentName, typeDefinition)
end

--[[
	Returns a new entity.
]]
function Registry:create()
	if self._nextRecyclableEntityId == NULL_ENTITYID then
		-- no entityIds to recycle
		local newEntity = self._size + 1
		self._size = newEntity
		self._entities[newEntity] = newEntity

		return newEntity
	else
		local entities = self._entities
		local recyclableEntityId = self._nextRecyclableEntityId
		local nextElement = entities[recyclableEntityId]
		local recycledEntity = bit32.bor(
			recyclableEntityId,
			bit32.lshift(bit32.rshift(nextElement, ENTITYID_WIDTH), ENTITYID_WIDTH)
		)

		entities[recyclableEntityId] = recycledEntity
		self._nextRecyclableEntityId = bit32.band(nextElement, ENTITYID_MASK)

		return recycledEntity
	end
end

--[[
	Returns a new entity equal to the given entity if and only if the given entity id is
	not in use by the registry. Otherwise, returns a new entity created normally.
]]
function Registry:createFrom(entity)
	local entityId = bit32.band(entity, ENTITYID_MASK)
	local entities = self._entities
	local existingEntityId = bit32.band(entities[entityId] or NULL_ENTITYID, ENTITYID_MASK)

	if existingEntityId == NULL_ENTITYID then
		-- The given id is out of range.
		local nextRecyclableEntityId = self._nextRecyclableEntityId

		-- _entities mustn't contain any gaps. If necessary, create the entities on the
		-- interval (size, entityId) and push them onto the recyclable list.
		for id = self._size + 1, entityId - 1 do
			entities[id] = nextRecyclableEntityId
			nextRecyclableEntityId = id
		end

		-- Now all we have to do is set the head of the recyclable list and append to
		-- _entities.
		self._nextRecyclableEntityId = nextRecyclableEntityId
		self._size = entityId
		entities[entityId] = entity

		return entity
	elseif existingEntityId == entityId then
		-- The id is currently in use. We should create a new entity normally and print
		-- out a warning because this is probably a mistake!
		local newEntity = self:create()

		if DEBUG then
			warn(debug.traceback(WarnEntityAlreadyExists:format(newEntity, entity), 3))
		end

		return newEntity
	else
		-- The id is currently available for recycling.
		local nextRecyclableEntityId = self._nextRecyclableEntityId

		if nextRecyclableEntityId == entityId then
			-- Pop the recyclable list. Done.
			self._nextRecyclableEntityId = bit32.band(entities[entityId], ENTITYID_MASK)
			entities[entityId] = entity
			return entity
		end

		-- Do a linear search of the recyclable list for entityId and take note of the
		-- previous element.
		local prevRecyclableEntityId

		while nextRecyclableEntityId ~= entityId do
			prevRecyclableEntityId = nextRecyclableEntityId
			nextRecyclableEntityId = bit32.band(
				self._entities[nextRecyclableEntityId],
				ENTITYID_MASK
			)
		end

		-- Make the previous element point to the next element, effectively removing
		-- entityId from the recyclable list.
		entities[prevRecyclableEntityId] = bit32.bor(
			bit32.band(entities[entityId], ENTITYID_MASK),
			bit32.lshift(
				bit32.rshift(entities[prevRecyclableEntityId], ENTITYID_WIDTH),
				ENTITYID_WIDTH
			)
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
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
	end

	local entityId = bit32.band(entity, ENTITYID_MASK)

	for _, pool in pairs(self._pools) do
		if pool:getIndex(entity) then
			pool.removed:dispatch(entity, pool:get(entity))
			pool:delete(entity)
		end
	end

	-- push this entityId onto the free list so that it can be recycled, and increment the
	-- identifier's version to avoid possible collision
	self._entities[entityId] = bit32.bor(
		self._nextRecyclableEntityId,
		bit32.lshift(bit32.rshift(entity, ENTITYID_WIDTH) + 1, ENTITYID_WIDTH)
	)

	self._nextRecyclableEntityId = entityId
end

--[[
	Returns true if the entity identifier corresponds to a valid entity. Otherwise,
	returns false.
]]
function Registry:valid(entity)
	if DEBUG then
		local ty = type(entity)
		jumpAssert(ty == "number", ErrBadEntityType:format(ty))
	end

	return self._entities[bit32.band(entity, ENTITYID_MASK)] == entity
end

--[[
	Returns true if the entity has no assigned components. Otherwise, returns false.
]]
function Registry:stub(entity)
	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
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
			jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
		end

		for componentName, pool in pairs(self._pools) do
			if pool:getIndex(entity) then
				local result = func(componentName)

				if result ~= nil then
					return result
				end
			end
		end
	else
		for componentName in pairs(self._pools) do
			local result = func(componentName)

			if result ~= nil then
				return result
			end
		end
	end
end

--[[
	Returns true if the entity has a component of all of the given types. Otherwise,
	returns false.
]]
function Registry:has(entity, ...)
	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))

		for i = 1, select("#", ...) do
			jumpAssert(self._pools[select(i, ...)], ErrBadComponentName:format(select(i, ...)))
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
	Returns true if the entity has a component of any of the given types. Otherwise,
	returns false.
]]
function Registry:any(entity, ...)
	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))

		for i = 1, select("#", ...) do
			jumpAssert(self._pools[select(i, ...)], ErrBadComponentName:format(select(i, ...)))
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
function Registry:get(entity, componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	return self._pools[componentName]:get(entity)
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
	Adds the component to the entity and returns the component. An entity may only have
	one component of each type at a time. Throws upon an attempt to add multiple
	components of the same type to an entity.
]]
function Registry:add(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(not pool:getIndex(entity), ErrAlreadyHasComponent:format(entity, componentName))
		jumpAssert(pool.typeCheck(component))
	end

	pool:insert(entity, component)
	pool.added:dispatch(entity, component)

	return component
end

function Registry:multiAdd(entity, componentMap)
	for componentName, component in pairs(componentMap) do
		self:add(entity, componentName, component)
	end

	return entity
end

--[[
	If the entity does not have the component, adds and returns the component. Otherwise,
	does nothing.
]]
function Registry:tryAdd(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(pool.typeCheck(component))
	end

	if pool:getIndex(entity) then
		return
	end

	pool:insert(entity, component)
	pool.added:dispatch(entity, component)

	return component
end

--[[
	If the entity has the component, returns the component. Otherwise adds the component
	to the entity and returns the component.
]]
function Registry:getOrAdd(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(pool.typeCheck(component))
	end

	local denseIndex = pool:getIndex(entity)

	if denseIndex then
		return pool.components[denseIndex]
	else
		pool:insert(entity, component)
		pool.added:dispatch(entity, component)

		return component
	end
end

--[[
	Replaces the component on the entity with the given component.

	Throws upon an attempt to replace a component that the entity does not have.
]]
function Registry:replace(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(pool.typeCheck(component))
		jumpAssert(pool:getIndex(entity), ErrMissingComponent:format(entity, componentName))
	end

	pool.updated:dispatch(entity, component)
	pool:replace(entity, component)

	return component
end

--[[
	If the entity has the component, replaces it with the given component and returns the
	new component. Otherwise, adds the component to the entity and returns the new
	component.
]]
function Registry:addOrReplace(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(pool.typeCheck(component))
	end

	local denseIndex = pool:getIndex(entity)

	if denseIndex then
		pool.updated:dispatch(entity, component)
		pool:replace(entity, component)
		return component
	end

	pool:insert(entity, component)
	pool.added:dispatch(entity, component)

	return component
end

--[[
	Removes the component from the entity.

	Throws upon an attempt to remove a component which the entity does not
	have.
]]
function Registry:remove(entity, componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(pool:getIndex(entity), ErrMissingComponent:format(entity, componentName))
	end

	pool.removed:dispatch(entity, pool:get(entity))
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
	If the entity has the component, removes it. Otherwise, does nothing.
]]
function Registry:tryRemove(entity, componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:valid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	if pool:getIndex(entity) then
		pool.removed:dispatch(entity, pool:get(entity))
		pool:delete(entity)

		return true
	end

	return false
end

--[[
	Returns the number of entities currently in use.
]]
function Registry:countEntities()
	local curr = self._nextRecyclableEntityId
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
	if self._nextRecyclableEntityId == NULL_ENTITYID then
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
	Returns a list of entities and a list of components. The lists are both in the same
	order, so that the component for the entity at dense[n] is at components[n].
]]
function Registry:raw(componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	return pool.dense, pool.components
end

--[[
	Returns the number of entities with the specified component.
]]
function Registry:count(componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	return pool.size
end

--[[
	Returns true if the registry manages a component named componentName. Otherwise,
	returns false.
]]
function Registry:hasDefined(componentName)
	return not not self._pools[componentName]
end

function Registry:getDefinition(componentName)
	local pool = self._pools[componentName]

	jumpAssert(pool, ErrBadComponentName:format(componentName))

	return pool.typeDefinition
end

--[[
	Returns a list of pools used to manage the specified components in the same order as
	the given tuple.
]]
function Registry:getPools(...)
	local n = select("#", ...)
	local output = table.create(n)

	for i = 1, n do
		local componentName = select(i, ...)
		local pool = self._pools[componentName]

		if DEBUG then
			jumpAssert(pool, ErrBadComponentName:format(componentName))
		end

		output[i] = pool
	end

	return output
end

function Registry:getPool(componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	return self._pools[componentName]
end

return Registry
