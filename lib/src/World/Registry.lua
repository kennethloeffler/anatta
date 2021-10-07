--[=[
	@class Registry
	A `Registry` manages entities and their components. It provides methods to create and
	destroy entities, and to add, remove, get, or update components on entities.

	You'll usually access a `Registry` from a [`World`](World).
]=]

local Constants = require(script.Parent.Parent.Core.Constants)
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

--- @prop _entities {[number]: number}
--- @within Registry
--- @private
--- @readonly
--- The list of all entities. Some of them may be destroyed. This field used to determine
--- if any given entity either exists and or has been destroyed.

--- @prop _pools {[string]: Pool}
--- @within Registry
--- @private
--- @readonly
--- A dictionary mapping component type names to the pools managing instances of the
--- components.

--- @prop _nextRecyclableEntityId number
--- @within Registry
--- @private
--- @readonly
--- The next ID to use when creating a new entity. When this field is equal to zero, it
--- means there are no IDs available to recycle.

--- @prop _size number
--- @within Registry
--- @private
--- @readonly
--- The total number of entities contained in [`_entities`](#_entities).

local Registry = {}
Registry.__index = Registry

--[=[
	Creates and returns a blank, empty registry.

	@return Registry
]=]
function Registry.new()
	return setmetatable({
		_entities = {},
		_pools = {},
		_nextRecyclableEntityId = NULL_ENTITYID,
		_size = 0,
	}, Registry)
end

--[=[
	Returns an integer equal to the first `ENTITYID_WIDTH` bits of the
	entity. The equality

	```lua
	registry._entities[id] == entity
	```

	generally holds if the entity is valid.

	@private
	@param entity number
	@return number
]=]
function Registry.getId(entity)
	return bit32.band(entity, ENTITYID_MASK)
end

--[=[
	Returns an integer equal to the last `32 - ENTITYID_WIDTH` bits of the
	entity.

	@private
	@param entity number
	@return number
]=]
function Registry.getVersion(entity)
	return bit32.rshift(entity, ENTITYID_WIDTH)
end

--[=[
	Creates a shallow copy of an existing registry.

	Because this function fires the added signal for every copied component, it
	is equivalent to adding each component to the new registry with
	[`addComponent`](#addComponent).

	#### Usage:
	```lua
	local entity1 = registry:createEntity()
	local health1 = registry:addComponent(entity1, "Health", 100)
	local inventory1 = registry:addComponent(entity1, "Inventory", { "Beans" })

	local entity2 = registry:createEntity()
	local health2 = registry:addComponent(entity1, "Health", 250)
	local inventory2 = registry:addComponent(entity2, "Inventory", { "Magic Beans", "Bass Guitar" })

	local copied = Registry.fromRegistry(registry)

	-- we now have an exact copy of the original registry
	assert(copied:isEntityValid(entity1) and copied:isEntityValid(entity2))

	local copiedHealth1, copiedInventory1 = registry:getComponents(entity1, "Health", "Inventory")
	local copiedHealth2, copiedInventory2 = registry:getComponents(entity1, "Health", "Inventory")

	assert(copiedHealth1 == health1 and copiedInventory1 == inventory1)
	assert(copiedHealth2 == health2 and copiedInventory2 == inventory2)
	```

	@param original Registry
	@return Registry
]=]
function Registry.fromRegistry(original)
	local newRegistry = Registry.new()

	newRegistry._size = original._size
	newRegistry._entities = original._entities
	newRegistry._nextRecyclableEntityId = original._nextRecyclableEntityId

	for _, originalPool in pairs(original._pools) do
		local componentName = originalPool.name

		newRegistry:defineComponent({
			name = originalPool.name,
			type = original.typeDefinition,
		})

		local copy = newRegistry:getPool(componentName)
		local checkSuccess, checkErr, failedEntity = true, "", 0

		for i, component in ipairs(originalPool.components) do
			local entity = originalPool.dense[i]
			local success, err = copy.typeCheck(component)

			if not success then
				checkSuccess, checkErr, failedEntity = false, err, entity
				break
			end
		end

		if checkSuccess then
			copy.size = originalPool.size

			for entity, index in pairs(originalPool.sparse) do
				copy.sparse[entity] = index
			end

			copy.dense = table.create(originalPool.size)
			table.move(originalPool.dense, 1, originalPool.size, 1, copy.dense)

			copy.components = table.create(originalPool.size)
			table.move(originalPool.components, 1, originalPool.size, 1, copy.components)

			for _, entity in ipairs(copy.dense) do
				copy.added:dispatch(entity, copy:get(entity))
			end
		else
			warn(("Type check for entity %s's %s failed: %s;\n\nSkipping component pool..."):format(
				failedEntity,
				componentName,
				checkErr
			))
			continue
		end
	end
end

--[=[
	Registers a new component type for the registry.

	#### Usage:
	```lua
	registry:defineComponent({
		name = "Health",
		type = t.number
	})

	local entity = registry:createEntity()

	registry:addComponent(entity, "Health", 100)
	```

	@private
	@param componentDefinition ComponentDefinition
]=]
function Registry:defineComponent(componentDefinition)
	local componentName = componentDefinition.name

	jumpAssert(not self._pools[componentName], ErrComponentNameTaken:format(componentName))

	self._pools[componentName] = Pool.new(
		componentName,
		componentDefinition.type,
		componentDefinition.meta
	)
end

--[=[
	Creates and returns a unique identifier that represents a game object.

	#### Usage:
	```lua
	local entity = registry:createEntity()
	assert(entity == 1)

	entity = registry:createEntity()
	assert(entity == 2)

	entity = registry:createEntity()
	assert(entity == 3)
	```

	@return number
]=]
function Registry:createEntity()
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

--[=[
	Returns an entity equal to the given entity.

	#### Usage:
	```lua
	local entity1 = registry:createEntity()
	registry:destroyEntity(entity1)
	assert(registry:createEntityFrom(entity1) == entity1)

	-- if entity with the same ID already exists, the existing entity is destroyed first
	local entity2 = registry:createEntity()
	registry:addComponent(entity2, "PrettyFly")

	entity2 = registry:createEntityFrom(entity2)
	assert(registry:entityHas(entity2, "PrettyFly") == false)
	```

	@private
	@param entity number
	@return number
]=]
function Registry:createEntityFrom(entity)
	local entityId = bit32.band(entity, ENTITYID_MASK)
	local entities = self._entities
	local existingEntityId = bit32.band(entities[entityId] or NULL_ENTITYID, ENTITYID_MASK)

	if existingEntityId == NULL_ENTITYID then
		-- The given id is out of range, so we'll have to backfill.
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
	end

	if existingEntityId == entityId then
		-- The id is currently in use. We should destroy the existing entity before continuing.
		self:destroyEntity(entity)
	end

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
		nextRecyclableEntityId = bit32.band(self._entities[nextRecyclableEntityId], ENTITYID_MASK)
	end

	-- Make the previous element point to the next element, effectively removing
	-- entityId from the recyclable list.
	entities[prevRecyclableEntityId] = bit32.bor(
		bit32.band(entities[entityId], ENTITYID_MASK),
		bit32.lshift(bit32.rshift(entities[prevRecyclableEntityId], ENTITYID_WIDTH), ENTITYID_WIDTH)
	)

	entities[entityId] = entity

	return entity
end

--[=[
	Removes all of an entity's components and frees its ID.

	#### Usage:
	```lua
	local entity = registry:create()

	registry:destroyEntity(entity)

	-- the entity is no longer valid and functions like getComponent or addComponent will throw
	assert(registry:isEntityValid(entity) == false)
	```

	@param entity number
]=]
function Registry:destroyEntity(entity)
	if DEBUG then
		jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))
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

--[=[
	Returns `true` if the entity exists. Otherwise, returns `false`.

	#### Usage:
	```lua
	assert(registry:isEntityValid(0) == false)

	local entity = registry:createEntity()

	assert(registry:isEntityValid(entity) == true)

	registry:destroyEntity(entity)

	assert(registry:isEntityValid(entity) == false)
	```

	@param entity number
	@return boolean
]=]
function Registry:isEntityValid(entity)
	if DEBUG then
		local ty = type(entity)
		jumpAssert(ty == "number", ErrBadEntityType:format(ty))
	end

	return self._entities[bit32.band(entity, ENTITYID_MASK)] == entity
end

--[=[
	Returns `true` if the entity has no components. Otherwise, returns `false`.

	#### Usage
	```lua
	local entity = registry:createEntity()

	assert(self:isEntityOrphaned(entity) == true)

	registry:addComponent(entity, "Car", {
		model = game.ReplicatedStorage.Car:Clone(),
		color = "Red",
	})

	assert(registry:isEntityOrphaned(entity) == false)
	```

	@param entity number
	@return boolean
]=]
function Registry:isEntityOrphaned(entity)
	if DEBUG then
		jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))
	end

	for _, pool in pairs(self._pools) do
		if pool:getIndex(entity) then
			return false
		end
	end

	return true
end

--[=[
	Passes all the component names defined on the registry to the given callback. The
	iteration continues until the callback returns `nil`.

	If an entity is given, passes only the components that the entity has.

	@param callback (componentName: string) -> boolean
	@param entity number?
	@return boolean
]=]
function Registry:visitComponents(callback, entity)
	if entity ~= nil then
		if DEBUG then
			jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))
		end

		for componentName, pool in pairs(self._pools) do
			if pool:getIndex(entity) then
				local shouldContinue = callback(componentName)

				if shouldContinue ~= nil then
					return shouldContinue
				end
			end
		end
	else
		for componentName in pairs(self._pools) do
			local shouldContinue = callback(componentName)

			if shouldContinue ~= nil then
				return shouldContinue
			end
		end
	end
end

--[=[
	Returns `true` if the entity all of the given components. Otherwise, returns `false`.

	@param entity number
	@param ...componentNames string
	@return boolean
]=]
function Registry:entityHas(entity, ...)
	if DEBUG then
		jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))

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

--[=[
	Returns `true` if the entity has any of the given components. Otherwise, returns
	`false`.

	@param entity number
	@param ...componentNames string
	@return boolean
]=]
function Registry:entityHasAny(entity, ...)
	if DEBUG then
		jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))

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

--[=[
	Returns the component of the given type on the entity.

	Throws if the entity does not have the component.

	@param entity number
	@param componentName string
	@return any
]=]
function Registry:getComponent(entity, componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	return self._pools[componentName]:get(entity)
end

--[=[
	Returns all of the given components on the entity.

	@param entity number
	@param output table
	@param ...componentNames string
	@return ...any
]=]
function Registry:getComponents(entity, output, ...)
	for i = 1, select("#", ...) do
		output[i] = self:getComponent(entity, select(i, ...))
	end

	return unpack(output)
end

--[=[
	Adds the component to the entity and returns the component. An entity may only have
	one component of each type at a time. Throws upon an attempt to add multiple
	components of the same type to an entity.

	@param entity number
	@param componentName string
	@param component any
	@return any
]=]
function Registry:addComponent(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(not pool:getIndex(entity), ErrAlreadyHasComponent:format(entity, componentName))
		jumpAssert(pool.typeCheck(component))
	end

	pool:insert(entity, component)
	pool.added:dispatch(entity, component)

	return component
end

--[=[
	Adds the given components to the entity and returns the entity.

	@param entity number
	@param components {[string]: any}
	@return number
]=]
function Registry:withComponents(entity, components)
	for componentName, component in pairs(components) do
		self:addComponent(entity, componentName, component)
	end

	return entity
end

--[=[
	If the entity does not have the component, adds and returns the component. Otherwise,
	returns `nil`.

	@param entity number
	@param componentName string
	@param component any
	@return any
]=]
function Registry:tryAddComponent(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(pool.typeCheck(component))
	end

	if not self:isEntityValid(entity) or pool:getIndex(entity) then
		return nil
	end

	pool:insert(entity, component)
	pool.added:dispatch(entity, component)

	return component
end

--[=[
	If the entity has the component, returns the component. Otherwise adds the component
	to the entity and returns the component.

	@param entity number
	@param componentName string
	@param component any
]=]
function Registry:getOrAddComponent(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))
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

--[=[
	Replaces the given component on the entity and returns the new component.

	Throws if the entity does not have the component.

	@param entity number
	@param componentName string
	@param component any
	@return any
]=]
function Registry:replaceComponent(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(pool.typeCheck(component))
		jumpAssert(pool:getIndex(entity), ErrMissingComponent:format(entity, componentName))
	end

	pool.updated:dispatch(entity, component)
	pool:replace(entity, component)

	return component
end

--[=[
	If the entity has the component, replaces it with the given component and returns the
	new component. Otherwise, adds the component to the entity and returns the new
	component.

	@param entity number
	@param componentName string
	@param component any
	@return any
]=]
function Registry:addOrReplaceComponent(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))
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

--[=[
	Removes the component from the entity.

	Throws if the entity does not have the component.

	@param entity number
	@param componentName string
]=]
function Registry:removeComponent(entity, componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isEntityValid(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(pool:getIndex(entity), ErrMissingComponent:format(entity, componentName))
	end

	local component = pool:get(entity)
	pool:delete(entity)
	pool.removed:dispatch(entity, component)
end

--[=[

	If the entity has the component, removes it and returns `true`. Otherwise, returns
	`false`.

	@param entity number
	@param componentName string
	@return boolean
]=]
function Registry:tryRemoveComponent(entity, componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	if self:isEntityValid(entity) and pool:getIndex(entity) then
		pool.removed:dispatch(entity, pool:get(entity))
		pool:delete(entity)
		return true
	end

	return false
end

--[=[
	Returns the total number of entities currently in use by the registry.

	@return number
]=]
function Registry:countEntities()
	local curr = self._nextRecyclableEntityId
	local num = self._size

	while curr ~= NULL_ENTITYID do
		num -= 1
		curr = bit32.band(self._entities[curr], ENTITYID_MASK)
	end

	return num
end

--[=[
	Returns the total number of entities with the given component.

	@param componentName string
	@return number
]=]
function Registry:countComponents(componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	return pool.size
end

--[=[
	Passes each entity currently in use by the registry to the given callback.

	@param callback (entity: number)
]=]
function Registry:each(callback)
	if self._nextRecyclableEntityId == NULL_ENTITYID then
		for _, entity in ipairs(self._entities) do
			callback(entity)
		end
	else
		for id, entity in ipairs(self._entities) do
			if bit32.band(entity, ENTITYID_MASK) == id then
				callback(entity)
			end
		end
	end
end

--[=[
	Returns `true` if the registry has a component named componentName. Otherwise,
	returns `false`.

	@param componentName string
	@return boolean
]=]
function Registry:isComponentDefined(componentName)
	return not not self._pools[componentName]
end

--[=[
	Returns the type definition of a component.

	@param componentName string
]=]
function Registry:getTypeDefinition(componentName)
	local pool = self._pools[componentName]

	jumpAssert(pool, ErrBadComponentName:format(componentName))

	return pool.typeDefinition
end

--[=[
	Returns a list of pools containing the specified components in the same order as
	the given list of component names.

	@param componentNames {string}
	@return {Pool}
]=]
function Registry:getPools(componentNames)
	local output = table.create(#componentNames)

	for i, componentName in ipairs(componentNames) do
		local pool = self._pools[componentName]

		if DEBUG then
			jumpAssert(pool, ErrBadComponentName:format(componentName))
		end

		output[i] = pool
	end

	return output
end

--[=[
	Returns the pool containing the specified components.

	@param componentName string
	@return Pool
]=]
function Registry:getPool(componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	return self._pools[componentName]
end

return Registry
