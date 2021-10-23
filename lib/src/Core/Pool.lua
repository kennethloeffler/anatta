--[=[
	@class Pool
	@private
	A `Pool` contains referernces to all the instances of a given `ComponentDefinition`.
	While heavily utilized internally, pools are really only useful for debugging outside of
	the library. Pools track only the entity that was assigned a component and its corresponding
	data.

	You can get a `Pool` from a [`Registry`](/api/Registry).
]=]

local Constants = require(script.Parent.Constants)
local Signal = require(script.Parent.Signal)

local ENTITYID_MASK = Constants.EntityIdMask

--- @prop componentDefinition ComponentDefinition
--- @within Pool
--- @private
--- @readonly
--- Contains the [ComponentDefinition](/api/Anatta#ComponentDefinition) assigned to this pool.

--- @prop added Signal
--- @within Pool
--- @private
--- @readonly
--- Fires when a component enters the pool. 
--- 
--- `Signal` is fired with the arguments `(entity: number, component: any)`

--- @prop removed Signal
--- @within Pool
--- @private
--- @readonly
--- Fires when a component leaves the pool
--- 
--- `Signal is fired with the argument `(entity: number, component: any)`

--- @prop updated Signal
--- @within Pool
--- @private
--- @readonly
--- Fires when a component changes
--- 
--- `Signal is fired with the argument `(entity: number, component: any)`

--- @prop size number
--- @within Pool
--- @private
--- @readonly
--- The current number of entities in a pool.

local Pool = {}
Pool.__index = Pool

--[=[
	@param componentDefinition ComponentDefinition
	@private

	Creates a new `Pool` for a [ComponentDefinition](/api/Anatta#ComponentDefinition)
]=]
function Pool.new(componentDefinition)
	return setmetatable({
		componentDefinition = componentDefinition,
		typeCheck = componentDefinition.type.check,

		added = Signal.new(),
		removed = Signal.new(),
		updated = Signal.new(),

		size = 0,
		sparse = {},
		dense = {},
		components = {},
	}, Pool)
end

--[=[
	Gets the index of the component within the pool for the given entity if it exists, otherwise returns `nil`.

	@param entity number
	@return number | nil
	@private
]=]
function Pool:getIndex(entity)
	return self.sparse[bit32.band(entity, ENTITYID_MASK)]
end

--[=[
	Gets the component within the pool for a given entity if it exists, otherwise returns `nil`.

	@param entity number
	@return any | nil
	@private
]=]
function Pool:get(entity)
	return self.components[self.sparse[bit32.band(entity, ENTITYID_MASK)]]
end

--[=[
	Replaces the component for a given entity in the pool. Will error if the entity does not exist in the pool.

	@param entity number
	@param component any
	@private
]=]
function Pool:replace(entity, component)
	self.components[self.sparse[bit32.band(entity, ENTITYID_MASK)]] = component
end

--[=[
	Inserts an entity into the pool for the given component. Then returns the component.

	@param entity number
	@param component any
	@return any
	@private
]=]
function Pool:insert(entity, component)
	self.size += 1

	local size = self.size
	local entityId = bit32.band(entity, ENTITYID_MASK)

	table.insert(self.dense, entity)
	table.insert(self.components, component)
	self.sparse[entityId] = size

	return component
end

--[=[
	Removes an entity from the pool.

	@param entity number
	@private
]=]
function Pool:delete(entity)
	self.size -= 1

	local prevSize = self.size + 1
	local entityId = bit32.band(entity, ENTITYID_MASK)
	local denseIdx = self.sparse[entityId]

	self.sparse[entityId] = nil

	if denseIdx < prevSize then
		local swapped = self.dense[prevSize]

		self.sparse[bit32.band(swapped, ENTITYID_MASK)] = denseIdx
		self.dense[denseIdx] = swapped
		self.components[denseIdx] = self.components[prevSize]
		self.dense[prevSize] = nil
		self.components[prevSize] = nil
	else
		table.remove(self.dense, prevSize)
		table.remove(self.components, prevSize)
	end
end

return Pool
