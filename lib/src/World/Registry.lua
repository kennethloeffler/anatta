--[[
	Registry.lua
]]
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

local WarnEntityAlreadyExists = "creating a new entity (%08X) because %08X's id is already in use"

--[=[
	@class Registry
]=]
local Registry = {}
Registry.__index = Registry

--[=[
	Creates and returns an empty registry.

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

	Usage:
	```lua
	```

	@tag Internal
	@param entity number
	@return number
]=]
function Registry.getId(entity)
	return bit32.band(entity, ENTITYID_MASK)
end

--[=[
	Returns an integer equal to the last `32 - ENTITYID_WIDTH` bits of the
	entity.

	Usage:
	```lua
	```

	@tag Internal
	@param entity number
	@return number
]=]
function Registry.getVersion(entity)
	return bit32.rshift(entity, ENTITYID_WIDTH)
end

--[=[
	Creates a new registry from an existing registry by making a shallow copy of
	each component pool. The added signal of each new component pool fires for
	each component that existed in the old component pool as if added via
	[`addComponent`](#addComponent) or similar.

	Usage:
	```lua
	```

	@tag Internal
	@param registry Registry
	@return Registry
]=]
function Registry.fromRegistry(registry)
	local newRegistry = Registry.new()

	newRegistry._size = registry._size
	newRegistry._entities = registry._entities
	newRegistry._nextRecyclableEntityId = registry._nextRecyclableEntityId

	for _, otherPool in pairs(registry._pools) do
		local componentName = otherPool.name

		if not newRegistry:isComponentDefined(componentName) then
			continue
		end

		local pool = newRegistry:getPool(componentName)
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

--[=[
	Registers a new component type for the registry.

	Usage:
	```lua
	```

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
	Creates and returns a new entity.

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
	Returns a new entity equal to the given entity if the given entity's ID is
	free to use. Otherwise, returns a new entity created via
	[`Registry:createEntity`](Registry#createEntity).

	@param entity number
	@return number
]=]
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
		-- The id is currently in use. We should create new entity normally and print
		-- out a warning because this is probably a mistake!
		local newEntity = self:createEntity()

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

--[=[
	Destroys an entity (and by extension, all of its components) and frees its ID.

	@param entity number
]=]
function Registry:destroyEntity(entity)
	if DEBUG then
		jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))
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

	@param entity number
	@return boolean
]=]
function Registry:isValidEntity(entity)
	if DEBUG then
		local ty = type(entity)
		jumpAssert(ty == "number", ErrBadEntityType:format(ty))
	end

	return self._entities[bit32.band(entity, ENTITYID_MASK)] == entity
end

--[=[
	Returns `true` if the entity has no components. Otherwise, returns `false`.

	@param entity number
	@return boolean
]=]
function Registry:isStubEntity(entity)
	if DEBUG then
		jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))
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
			jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))
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
function Registry:hasAllComponents(entity, ...)
	if DEBUG then
		jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))

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
function Registry:hasAnyComponents(entity, ...)
	if DEBUG then
		jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))

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
	@return Component<Type>
]=]
function Registry:getComponent(entity, componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	return self._pools[componentName]:get(entity)
end

--[=[
	Returns all of the given components on the entity.

	@param entity number
	@param output table
	@param ...componentNames string
	@return ...Component<Type>
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
	@param component Component<Type>
	@return Component<Type>
]=]
function Registry:addComponent(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))
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
	@param componentMap {[string]: Component<Type>}
	@return number
]=]
function Registry:addComponents(entity, componentMap)
	for componentName, component in pairs(componentMap) do
		self:addComponent(entity, componentName, component)
	end

	return entity
end

--[=[
	If the entity does not have the component, adds and returns the component. Otherwise,
	returns `nil`.

	@param entity number
	@param componentName string
	@param component Component<Type>
	@return Component<Type> | nil
]=]
function Registry:tryAddComponent(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentName:format(componentName))
		jumpAssert(pool.typeCheck(component))
	end

	if not self:isValidEntity(entity) or pool:getIndex(entity) then
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
	@param component Component<Type>
]=]
function Registry:getOrAddComponent(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))
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
	@param component Component<Type>
	@return Component<Type>
]=]
function Registry:replaceComponent(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))
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
	@param component Component<Type>
	@return Component<Type>
]=]
function Registry:addOrReplaceComponent(entity, componentName, component)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))
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
		jumpAssert(self:isValidEntity(entity), ErrInvalidEntity:format(entity))
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

	if self:isValidEntity(entity) and pool:getIndex(entity) then
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

function Registry:getComponentDefinition(componentName)
	local pool = self._pools[componentName]

	jumpAssert(pool, ErrBadComponentName:format(componentName))

	return pool.typeDefinition
end

--[=[
	Returns a list of pools containing the specified components in the same order as
	the given list of component names.

	@tag Internal
	@param componentNames {string}
	@return {Pool<Type>}
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

	@tag Internal
	@param componentName string
	@return Pool<Type>
]=]
function Registry:getPool(componentName)
	local pool = self._pools[componentName]

	if DEBUG then
		jumpAssert(pool, ErrBadComponentName:format(componentName))
	end

	return self._pools[componentName]
end

return Registry
