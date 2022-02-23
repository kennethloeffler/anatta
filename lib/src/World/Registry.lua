--[=[
	@class Registry
	A `Registry` manages and provides unscoped access to entities and their components. It
	provides methods to create and destroy entities and to add, remove, get, or update
	components.

	You can get a `Registry` from a [`World`](/api/World).
]=]

local Constants = require(script.Parent.Parent.Core.Constants)
local Pool = require(script.Parent.Parent.Core.Pool)
local Types = require(script.Parent.Parent.Types)
local util = require(script.Parent.Parent.util)
local t = require(script.Parent.Parent.Parent.t)

local jumpAssert = util.jumpAssert

local DEBUG = Constants.Debug
local DOMAIN_OFFSET = Constants.DomainOffset
local DOMAIN_WIDTH = Constants.DomainWidth
local DOMAIN = Constants.Domain
local PARTIALID_WIDTH = Constants.PartialIdWidth
local ENTITYID_OFFSET = Constants.EntityIdOffset
local ENTITYID_WIDTH = Constants.EntityIdWidth
local VERSION_OFFSET = Constants.VersionOffset
local VERSION_WIDTH = Constants.VersionWidth
local NULL_ENTITYID = Constants.NullEntityId

local DomainNames = {
	"server",
	"client",
}

local ExpectedDomainName = DomainNames[DOMAIN + 1]
local WrongDomainName = DomainNames[math.abs(DOMAIN - 1) + 1]

local ErrAlreadyHasComponent = "entity %d already has a %s"
local ErrBadComponentDefinition = 'the component type "%s" is not defined for this registry'
local ErrComponentNameTaken = "there is already a component type named %s"
local ErrEntityNotANumber = "expected entity to be a number, got %s"
local ErrInvalidEntity = "entity %d does not exist or has been destroyed"
local ErrMissingComponent = "entity %d does not have a %s"
local ErrWrongDomain = "entity %d comes from the wrong domain; came from a %s, but this registry is a %s"

local ComponentDefinitionToString = {
	__tostring = function(definition)
		return ("%s: %s"):format(definition.name, definition.type.typeName)
	end,
}

--- @prop _entities {[number]: number}
--- @within Registry
--- @private
--- @readonly
--- The list of all entities. Some of them may be destroyed. This property is used to
--- determine if any given entity exists or has been destroyed.

--- @prop _pools {[ComponentDefinition]: Pool}
--- @within Registry
--- @private
--- @readonly
--- A dictionary mapping component type names to the pools managing instances of the
--- components.

--- @prop _nextRecyclableEntityId number
--- @within Registry
--- @private
--- @readonly
--- The next ID to use when creating a new entity. When this property is equal to zero, it
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

	@ignore
	@return Registry
]=]
function Registry.new()
	return setmetatable({
		_entities = {},
		_pools = {},
		_nextRecyclableEntityId = NULL_ENTITYID,
		_size = 0,
		_foreignCount = 0,
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
	return bit32.extract(entity, ENTITYID_OFFSET, ENTITYID_WIDTH)
end

--[=[
	Returns an integer equal to the last `32 - ENTITYID_WIDTH` bits of the
	entity.

	@private
	@param entity number
	@return number
]=]
function Registry.getVersion(entity)
	return bit32.extract(entity, VERSION_OFFSET, VERSION_WIDTH)
end

--[=[
	Returns the domain of an entity. 0 = client; 1 = server

	@private
	@param entity number
	@return number
]=]
function Registry.getDomain(entity)
	return bit32.extract(entity, DOMAIN_OFFSET, DOMAIN_WIDTH)
end

--[=[
	Creates a shallow copy of an existing registry.

	Because this function fires the added signal for every copied component, it
	is equivalent to adding each component to the new registry with
	[`addComponent`](#addComponent).

	#### Usage:
	```lua
	local entity1 = registry:createEntity()
	local health1 = registry:addComponent(entity1, Health, 100)
	local inventory1 = registry:addComponent(entity1, Inventory, { "Beans" })

	local entity2 = registry:createEntity()
	local health2 = registry:addComponent(entity1, Health, 250)
	local inventory2 = registry:addComponent(entity2, Inventory, { "Magic Beans", "Bass Guitar" })

	local copied = Registry.fromRegistry(registry)

	-- we now have an exact copy of the original registry
	assert(copied:entityIsValid(entity1) and copied:entityIsValid(entity2))

	local copiedHealth1, copiedInventory1 = registry:getComponents(entity1, Health, Inventory)
	local copiedHealth2, copiedInventory2 = registry:getComponents(entity1, Health, Inventory)

	assert(copiedHealth1 == health1 and copiedInventory1 == inventory1)
	assert(copiedHealth2 == health2 and copiedInventory2 == inventory2)
	```

	@ignore
	@param original Registry
	@return Registry
]=]
function Registry.fromRegistry(original)
	local newRegistry = Registry.new()

	newRegistry._size = original._size
	newRegistry._entities = original._entities
	newRegistry._nextRecyclableEntityId = original._nextRecyclableEntityId

	for _, originalPool in pairs(original._pools) do
		local definition = originalPool.definition

		newRegistry:defineComponent(definition)

		local copy = newRegistry:getPool(definition)
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
			warn(
				("Type check for entity %s's %s failed: %s;\n\nSkipping component pool..."):format(
					failedEntity,
					definition,
					checkErr
				)
			)
			continue
		end
	end
end

--[=[
	Defines a new component type for the registry using the given
	[`ComponentDefinition`](/api/Anatta#ComponentDefinition).

	#### Usage:
	```lua
	local Health = registry:defineComponent({
		name = "Health",
		type = t.number
	})

	registry:addComponent(registry:createEntity(), Health, 100)
	```

	@private
	@error "there is already a component type named %s" -- The name is already being used.

	@param definition ComponentDefinition
]=]
function Registry:defineComponent(definition)
	jumpAssert(Types.ComponentDefinition(definition))

	local isNameUnique = true

	for existingDefinition in pairs(self._pools) do
		if existingDefinition.name == definition.name then
			isNameUnique = false
			break
		end
	end

	jumpAssert(isNameUnique, ErrComponentNameTaken, definition.name)

	setmetatable(definition, ComponentDefinitionToString)
	self._pools[definition] = Pool.new(definition)

	return definition
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
		local newPartialId = self._size + 1
		self._size = newPartialId

		-- quit out if the partial ID goes above the maximum allocated space in
		-- partial ID
		jumpAssert(newPartialId < 2 ^ PARTIALID_WIDTH - 1, "exceeded entity partial id maximum")

		-- append the domain to the right side of the partial ID to form
		-- the complete entity ID
		local newEntityId = bit32.replace(bit32.lshift(newPartialId, DOMAIN_WIDTH), DOMAIN, DOMAIN_OFFSET, DOMAIN_WIDTH)

		self._entities[newEntityId] = newEntityId

		return newEntityId
	else
		local entities = self._entities
		local recyclableEntityId = self._nextRecyclableEntityId
		local nextElement = entities[recyclableEntityId]

		local recycledEntity = bit32.replace(
			recyclableEntityId,
			bit32.extract(nextElement, ENTITYID_WIDTH, 32 - ENTITYID_WIDTH),
			ENTITYID_WIDTH,
			32 - ENTITYID_WIDTH
		)

		entities[recyclableEntityId] = recycledEntity
		self._nextRecyclableEntityId = bit32.extract(nextElement, ENTITYID_OFFSET, ENTITYID_WIDTH)

		return recycledEntity
	end
end

--[=[
	Imports an entity from a different domain. These are not recycled.

	@private
	@param entity number
	@return number
]=]
function Registry:importEntity(entity)
	jumpAssert(t.number(entity))
	jumpAssert(
		bit32.extract(entity, DOMAIN_OFFSET, DOMAIN_WIDTH) ~= DOMAIN,
		ErrWrongDomain,
		entity,
		WrongDomainName,
		ExpectedDomainName
	)

	local entityId = bit32.extract(entity, ENTITYID_OFFSET, ENTITYID_WIDTH)
	local entities = self._entities

	jumpAssert(entities[entityId] == nil, "attempt to import an existing entity: %d", entity)

	entities[entityId] = entity

	self._foreignCount += 1

	return entity
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
	registry:addComponent(entity2, PrettyFly)

	entity2 = registry:createEntityFrom(entity2)
	assert(registry:entityHas(entity2, PrettyFly) == false)
	```

	@private
	@param entity number
	@return number
]=]
function Registry:createEntityFrom(entity)
	jumpAssert(t.number(entity))
	jumpAssert(
		bit32.extract(entity, DOMAIN_OFFSET, DOMAIN_WIDTH) == DOMAIN,
		ErrWrongDomain,
		entity,
		WrongDomainName,
		ExpectedDomainName
	)

	local entityId = bit32.extract(entity, ENTITYID_OFFSET, ENTITYID_WIDTH)
	local entities = self._entities
	local existingEntityId = bit32.extract(entities[entityId] or NULL_ENTITYID, ENTITYID_OFFSET, ENTITYID_WIDTH)

	if existingEntityId == NULL_ENTITYID then
		-- The given id is out of range, so we'll have to backfill.
		local nextRecyclableEntityId = self._nextRecyclableEntityId

		-- _entities mustn't contain any gaps. If necessary, create the entities on the
		-- interval (size, entityId) and push them onto the recyclable list.
		for newPartialId = self._size + 1, bit32.rshift(entityId, DOMAIN_WIDTH) - 1 do
			local newId = bit32.replace(bit32.lshift(newPartialId, DOMAIN_WIDTH), DOMAIN, DOMAIN_OFFSET, DOMAIN_WIDTH)

			entities[newId] = nextRecyclableEntityId
			nextRecyclableEntityId = newId
		end

		-- Now all we have to do is set the head of the recyclable list and append to
		-- _entities.
		self._nextRecyclableEntityId = nextRecyclableEntityId
		self._size = bit32.rshift(entityId, DOMAIN_WIDTH)

		entities[entityId] = entity

		return entity
	end

	if existingEntityId == entityId and self:entityIsValid(entity) then
		-- The id is currently in use. We should destroy the existing entity before continuing.
		self:destroyEntity(entity)
	end

	-- The id is currently available for recycling.
	local nextRecyclableEntityId = self._nextRecyclableEntityId

	if nextRecyclableEntityId == entityId then
		-- Pop the recyclable list. Done.
		self._nextRecyclableEntityId = bit32.extract(entities[entityId], ENTITYID_OFFSET, ENTITYID_WIDTH)

		entities[entityId] = entity

		return entity
	end

	-- Do a linear search of the recyclable list for entityId and take note of the
	-- previous element.
	local prevRecyclableEntityId

	while nextRecyclableEntityId ~= entityId do
		prevRecyclableEntityId = nextRecyclableEntityId
		nextRecyclableEntityId = bit32.extract(self._entities[nextRecyclableEntityId], ENTITYID_OFFSET, ENTITYID_WIDTH)
	end

	-- Make the previous element point to the next element, effectively removing
	-- entityId from the recyclable list.
	entities[prevRecyclableEntityId] = bit32.replace(
		bit32.extract(entities[entityId], ENTITYID_OFFSET, ENTITYID_WIDTH),
		bit32.extract(entities[prevRecyclableEntityId], ENTITYID_WIDTH, 32 - ENTITYID_WIDTH),
		ENTITYID_WIDTH,
		32 - ENTITYID_WIDTH
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
	assert(registry:entityIsValid(entity) == false)
	```

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.

	@param entity number
]=]
function Registry:destroyEntity(entity)
	if DEBUG then
		jumpAssert(self:entityIsValid(entity), ErrInvalidEntity, entity)
	end

	local entityId = Registry.getId(entity)

	-- remove from all pools
	for _, pool in pairs(self._pools) do
		if pool:getIndex(entity) then
			local component = pool:get(entity)

			pool:delete(entity)
			pool.removed:dispatch(entity, component)
		end
	end

	-- Replicated entities should not be recycled.
	-- We can safely throw them out since they are not part of the
	-- recycling stack.
	if Registry.getDomain(entity) ~= DOMAIN then
		self._entities[entityId] = nil

		self._foreignCount -= 1

		return
	end

	-- push this entityId onto the recycling stack so that it can be recycled, and increment the
	-- identifier's version to avoid possible collision
	--
	-- self._entities[entityId] points to the previous next recyclableEntityId
	-- switches to format:
	--
	-- VERSION   POINTER
	-- |-------| |---------------------------|
	-- VVVV VVVV PPPP PPPP PPPP PPPP PPPP PPPP
	self._entities[entityId] = bit32.replace(
		self._nextRecyclableEntityId, -- entity ID width
		bit32.extract(entity, VERSION_OFFSET, VERSION_WIDTH) + 1,
		VERSION_OFFSET,
		VERSION_WIDTH
	)

	self._nextRecyclableEntityId = entityId
end

--[=[
	Returns `true` if the entity exists. Otherwise, returns `false`.

	#### Usage:
	```lua
	assert(registry:entityIsValid(0) == false)

	local entity = registry:createEntity()

	assert(registry:entityIsValid(entity) == true)

	registry:destroyEntity(entity)

	assert(registry:entityIsValid(entity) == false)
	```

	@param entity number
	@return boolean, string, number, string?, string?
]=]
function Registry:entityIsValid(entity)
	if typeof(entity) ~= "number" then
		return false, ErrEntityNotANumber, entity
	end

	local entityId = Registry.getId(entity)

	if self._entities[entityId] ~= entity then
		return false, ErrInvalidEntity, entity
	end

	return true, "", entity
end

--[=[
	Returns `true` if the entity has no components. Otherwise, returns `false`.

	#### Usage
	```lua
	local entity = registry:createEntity()

	assert(self:entityIsOrphaned(entity) == true)

	registry:addComponent(entity, Car, {
		model = game.ReplicatedStorage.Car:Clone(),
		color = "Red",
	})

	assert(registry:entityIsOrphaned(entity) == false)
	```

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.

	@param entity number
	@return boolean
]=]
function Registry:entityIsOrphaned(entity)
	if DEBUG then
		jumpAssert(self:entityIsValid(entity))
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

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.

	@param callback (definition: ComponentDefinition) -> boolean
	@param entity number?
	@return boolean
]=]
function Registry:visitComponents(callback, entity)
	if entity ~= nil then
		if DEBUG then
			jumpAssert(self:entityIsValid(entity))
		end

		for definition, pool in pairs(self._pools) do
			if pool:getIndex(entity) then
				local shouldContinue = callback(definition)

				if shouldContinue ~= nil then
					return shouldContinue
				end
			end
		end
	else
		for definition in pairs(self._pools) do
			local shouldContinue = callback(definition)

			if shouldContinue ~= nil then
				return shouldContinue
			end
		end
	end
end

--[=[
	Returns `true` if the entity all of the given components. Otherwise, returns `false`.

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.

	@param entity number
	@param ... ComponentDefinition
	@return boolean
]=]
function Registry:entityHas(entity, ...)
	if DEBUG then
		jumpAssert(self:entityIsValid(entity))

		for i = 1, select("#", ...) do
			jumpAssert(self._pools[select(i, ...)], ErrBadComponentDefinition, select(i, ...))
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

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.

	@param entity number
	@param ... ComponentDefinition
	@return boolean
]=]
function Registry:entityHasAny(entity, ...)
	if DEBUG then
		jumpAssert(self:entityIsValid(entity))

		for i = 1, select("#", ...) do
			jumpAssert(self._pools[select(i, ...)], ErrBadComponentDefinition, select(i, ...))
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

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.

	@param entity number
	@param definition ComponentDefinition
	@return any
]=]
function Registry:getComponent(entity, definition)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(self:entityIsValid(entity))
		jumpAssert(pool, ErrBadComponentDefinition, definition)
	end

	return self._pools[definition]:get(entity)
end

--[=[
	Returns all of the given components on the entity.

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.

	@param entity number
	@param output table
	@param ... ComponentDefinition
	@return ...any
]=]
function Registry:getComponents(entity, output, ...)
	for i = 1, select("#", ...) do
		output[i] = self:getComponent(entity, select(i, ...))
	end

	return unpack(output)
end

--[=[
	Adds a component to the entity and returns the component.

	:::info
	An entity can only have one component of each type at a time.

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.
	@error "entity %d already has a %s" -- The entity already has that component.
	@error Failed type check -- The given component has the wrong type.

	@param entity number
	@param definition ComponentDefinition
	@param component any
	@return any
]=]
function Registry:addComponent(entity, definition, component)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(self:entityIsValid(entity))
		jumpAssert(pool, ErrBadComponentDefinition, definition)
		jumpAssert(not pool:getIndex(entity), ErrAlreadyHasComponent, entity, definition)
		jumpAssert(pool.typeCheck(component))
	end

	pool:insert(entity, component)
	pool.added:dispatch(entity, component)

	return component
end

--[=[
	Adds the given components to the entity and returns the entity.

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.
	@error "entity %d already has a %s" -- The entity already has that component.
	@error Failed type check -- The given component has the wrong type.

	@param entity number
	@param components {[ComponentDefinition]: any}
	@return number
]=]
function Registry:withComponents(entity, components)
	for definition, component in pairs(components) do
		self:addComponent(entity, definition, component)
	end

	return entity
end

--[=[
	If the entity does not have the component, adds and returns the component. Otherwise,
	returns `nil`.

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.
	@error Failed type check -- The given component has the wrong type.

	@param entity number
	@param definition ComponentDefinition
	@param component any
	@return any
]=]
function Registry:tryAddComponent(entity, definition, component)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentDefinition, definition)
		jumpAssert(pool.typeCheck(component))
	end

	if not self:entityIsValid(entity) or pool:getIndex(entity) then
		return nil
	end

	pool:insert(entity, component)
	pool.added:dispatch(entity, component)

	return component
end

--[=[
	If the entity has the component, returns the component. Otherwise adds the component
	to the entity and returns the component.

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.
	@error Failed type check -- The given component has the wrong type.

	@param entity number
	@param definition ComponentDefinition
	@param component any
]=]
function Registry:getOrAddComponent(entity, definition, component)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(self:entityIsValid(entity))
		jumpAssert(pool, ErrBadComponentDefinition, definition)
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

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.
	@error Failed type check -- The given component has the wrong type.
	@error "entity %d does not have a %s" -- The entity is expected to have this component.

	@param entity number
	@param definition ComponentDefinition
	@param component any
	@return any
]=]
function Registry:replaceComponent(entity, definition, component)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(self:entityIsValid(entity))
		jumpAssert(pool, ErrBadComponentDefinition, definition)
		jumpAssert(pool.typeCheck(component))
		jumpAssert(pool:getIndex(entity), ErrMissingComponent, entity, definition)
	end

	pool:replace(entity, component)
	pool.updated:dispatch(entity, component)

	return component
end

--[=[
	If the entity has the component, replaces it with the given component and returns the
	new component. Otherwise, adds the component to the entity and returns the new
	component.

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.
	@error Failed type check -- The given component has the wrong type.

	@param entity number
	@param definition ComponentDefinition
	@param component any
	@return any
]=]
function Registry:addOrReplaceComponent(entity, definition, component)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(self:entityIsValid(entity))
		jumpAssert(pool, ErrBadComponentDefinition, definition)
		jumpAssert(pool.typeCheck(component))
	end

	local denseIndex = pool:getIndex(entity)

	if denseIndex then
		pool:replace(entity, component)
		pool.updated:dispatch(entity, component)
		return component
	end

	pool:insert(entity, component)
	pool.added:dispatch(entity, component)

	return component
end

--[=[
	Adds the component to the entity, immediately replacing the component with itself, and
	returns the component.

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.
	@error "entity %d already has a %s" -- The entity already has that component.
	@error Failed type check -- The given component has the wrong type.

	@param entity number
	@param definition ComponentDefinition
	@param component any
	@return any
]=]
function Registry:addAndReplaceComponent(entity, definition, component)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(self:entityIsValid(entity))
		jumpAssert(pool, ErrBadComponentDefinition, definition)
		jumpAssert(not pool:getIndex(entity), ErrAlreadyHasComponent, entity, definition)
		jumpAssert(pool.typeCheck(component))
	end

	pool:insert(entity, component)
	pool.added:dispatch(entity, component)
	pool.updated:dispatch(entity, component)

	return component
end

--[=[
	Removes the component from the entity.

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.
	@error "entity %d does not have a %s" -- The entity is expected to have this component.

	@param entity number
	@param definition ComponentDefinition
]=]
function Registry:removeComponent(entity, definition)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(self:entityIsValid(entity))
		jumpAssert(pool, ErrBadComponentDefinition, definition)
		jumpAssert(pool:getIndex(entity), ErrMissingComponent, entity, definition)
	end

	local component = pool:get(entity)
	pool:delete(entity)
	pool.removed:dispatch(entity, component)
end

--[=[
	If the entity has the component, removes it and returns `true`. Otherwise, returns
	`false`.

	@error "expected entity to be a number, got %s" -- The entity is not a number.
	@error "entity %d does not exist or has been destroyed" -- The entity is invalid.
	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.

	@param entity number
	@param definition ComponentDefinition
	@return boolean
]=]
function Registry:tryRemoveComponent(entity, definition)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentDefinition, definition)
	end

	if self:entityIsValid(entity) and pool:getIndex(entity) then
		local component = pool:get(entity)

		pool:delete(entity)
		pool.removed:dispatch(entity, component)

		return true
	end

	return false
end

--[=[
	Returns the total number of entities currently in use by the registry.

	@return number
]=]
function Registry:countEntities()
	local entityId = self._nextRecyclableEntityId
	local count = self._size + self._foreignCount

	while entityId ~= NULL_ENTITYID do
		entityId = bit32.extract(self._entities[entityId], ENTITYID_OFFSET, ENTITYID_WIDTH)
		count -= 1
	end

	return count
end

--[=[
	Returns the total number of entities with the given component.

	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.

	@param definition ComponentDefinition
	@return number
]=]
function Registry:countComponents(definition)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentDefinition, definition)
	end

	return pool.size
end

--[=[
	Passes each entity currently in use by the registry to the given callback.

	@param callback (entity: number) -> ()
]=]
function Registry:each(callback)
	if self._nextRecyclableEntityId == NULL_ENTITYID then
		for _, entity in pairs(self._entities) do
			callback(entity)
		end
	else
		for id, entity in pairs(self._entities) do
			if bit32.extract(entity, ENTITYID_OFFSET, ENTITYID_WIDTH) == id then
				callback(entity)
			end
		end
	end
end

--[=[
	Returns `true` if the registry has a component type with the given name. Otherwise,
	returns `false`.

	@param definition ComponentDefinition
	@return boolean
]=]
function Registry:isComponentDefined(definition)
	return not not self._pools[definition]
end

--[=[
	Returns a list of the `Pool`s used to manage the given components.

	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.

	@private
	@param definitions {string}
	@return {Pool}
]=]
function Registry:getPools(definitions)
	local output = table.create(#definitions)

	for i, definition in ipairs(definitions) do
		local pool = self._pools[definition]

		if DEBUG then
			jumpAssert(pool, ErrBadComponentDefinition, definition)
		end

		output[i] = pool
	end

	return output
end

--[=[
	Returns the `Pool` containing the given components.

	@error 'the component type "%s" is not defined for this registry' -- No component matches that definition.

	@private
	@param definition ComponentDefinition
	@return Pool
]=]
function Registry:getPool(definition)
	local pool = self._pools[definition]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentDefinition, definition)
	end

	return self._pools[definition]
end

return Registry
