--[[

 Manifest.lua

 TODO: luau types

 TODO: groups?

]]

local Constants = require(script.Parent.Parent.Constants)
local Pool = require(script.Parent.Pool)
local Identify = require(script.Parent.Parent.core.Identify)
local View = require(script.Parent.View)

local DEBUG = Constants.DEBUG
local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
local ENTITYID_MASK = Constants.ENTITYID_MASK
local NULL_ENTITYID = Constants.NULL_ENTITYID

local ErrAlreadyHas = "entity %X already has this component"
local ErrBadComponentId = "invalid component identifier"
local ErrInvalid = "entity %X either does not exist or it has been destroyed"
local ErrMissing = "entity %X does not have this component"
local ErrBadType = "bad type: expected %s (got %s)"

local getPool
local assign = Pool.Assign
local destroy = Pool.Destroy
local get = Pool.Get
local has = Pool.Has
local generateComponentId = Identify.GenerateRuntime

local Manifest = {}

Manifest.__index = Manifest

function Manifest.new()
	return setmetatable({
		Size = 0,
		Head = NULL_ENTITYID,
		Entities = {},
		Pools = {},
		Component = {}
	}, Manifest)
end


function Manifest:DefineComponent(name, dataType)
	if self.Component[name] then
		return
	end

	local componentId = generateComponentId(name)

	self.Component[name] = componentId
	self.Pools[componentId] = Pool.new(dataType)

	return componentId
end

--[[

 Return a new valid entity identifier

 Entity ids are recycled after they are no longer in use to prevent
 boundless growth of self.Entities.  This is done by implicitly
 maintaining a stack in self.Entities; each element points to the next
 available id.

]]
function Manifest:Create()
	local entities = self.Entities
	local entityId = self.Head

	if entityId == NULL_ENTITYID then
		-- no entity ids to recycle, generate a new one
		entityId = self.Size + 1
		self.Size = entityId
		entities[entityId] = entityId

		return entityId
	end

	local identifier = entities[entityId]
	local version = bit32.lshift(bit32.rshift(identifier, ENTITYID_WIDTH), ENTITYID_WIDTH)
	local recycled = bit32.bor(entityId, version)

	-- pop the next id off the stack
	self.Head = bit32.band(identifier, ENTITYID_MASK)
	entities[entityId] = recycled

	return recycled
end

--[[

 Destroy the entity, and by extension, all its components

]]
function Manifest:Destroy(entity)
	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))
	end

	local entityId = bit32.band(entity, ENTITYID_MASK)

	for _, pool in ipairs(self.Pools) do
		if has(pool, entity) then
			pool.OnRemove:Dispatch(self, entity)
			destroy(pool, entity)
		end
	end

	-- push this id onto the stack
	self.Entities[entityId] = bit32.bor(
		self.Head,
		bit32.lshift(bit32.rshift(entity, ENTITYID_WIDTH) + 1,
				   ENTITYID_WIDTH))

	self.Head = entityId
end

--[[

 If the entity is alive, return true; otherwise return false

]]
function Manifest:Valid(entity)
	local id = bit32.band(entity, ENTITYID_MASK)

	return id <= self.Size and self.Entities[id] == entity
end

--[[

 If the entity has no assigned components, return true; otherwise
 return false

]]
function Manifest:Orphan(entity)
  	for _, pool in ipairs(self.Pools) do
		if has(pool, entity) then
			return false
		end
	end

	return true
end

--[[

 If the entity has the component, return true; otherwise return false

]]
function Manifest:Has(entity, componentId)
	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))
	end

	return not not has(getPool(self, componentId), entity)
end

--[[

 If the entity has the component, return it; otherwise return nil

]]
function Manifest:Get(entity, componentId)
	local pool = getPool(self, componentId)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))
	end

	return get(pool, entity)
end

--[[

 Assign a component to the entity

 Assigning to an entity that already has the component is undefined.

]]
function Manifest:Assign(entity, componentId, component)
	local pool = getPool(self, componentId)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))

		assert(not has(pool, entity), ErrAlreadyHas:format(entity))

		-- just basic type checking for now
		assert(pool.Type == nil or pool.Type == typeof(component),
			  ErrBadType:format(pool.Type or "", typeof(component)))
	end

	local obj = assign(pool, entity, component)

	pool.OnAssign:Dispatch(self, entity)

	return obj
end

--[[

 If the entity already has the component, return it; otherwise assign
 and return it

]]
function Manifest:GetOrAssign(entity, componentId, component)
	local pool = getPool(self, componentId)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))

		assert(pool.Type == nil or pool.Type == typeof(component),
			  ErrBadType:format(pool.Type or "", typeof(component)))
	end

	local exists = has(pool, entity)
	local obj = get(pool, entity)

	-- boolean operators won't work here, b/c obj can be nil if the
	-- component is empty (i.e. it's a "flag" component)
	if exists then
		return obj
	else
		obj = assign(pool, entity, component)

		pool.OnAssign:Dispatch(self, entity)

		return obj
	end
end

--[[

 Replace the component assigned to the entity with a new one

 Replacing a component which is not assigned to the entity is
 undefined.

]]
function Manifest:Replace(entity, componentId, component)
	local pool = getPool(self, componentId)
	local index = has(pool, entity)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))

		assert(pool.Type == nil or pool.Type == typeof(component),
			  ErrBadType:format(pool.Type or "", typeof(component)))

		assert(index, ErrMissing:format(entity))
	end

	if pool.Objects then
		pool.Objects[index] = component
	end

	pool.OnUpdate:Dispatch(self, entity)

	return component
end

--[[

 If the entity has the component, replace and return it; otherweise,
 assign and return it

]]
function Manifest:ReplaceOrAssign(entity, componentId, component)
	local pool = getPool(self, componentId)
	local index = has(pool, entity)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))

		assert(pool.Type == nil or pool.Type == typeof(component),
			  ErrBadType:format(pool.Type or "", typeof(component)))
	end

	if index then
		if pool.Objects then
			pool.Objects[index] = component
		end

		pool.OnUpdate:Dispatch(self, entity)

		return component
	end

	local obj = assign(pool, entity, component)

	pool.OnAssign:Dispatch(self, entity)

	return obj
end

--[[

 Remove the component from the entity

 Removing a component which is not assigned to the entity is
 undefined.

]]
function Manifest:Remove(entity, componentId)
	local pool = getPool(self, componentId)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))

		assert(has(pool, entity), ErrMissing:format(entity))
	end

	destroy(pool, entity)

	pool.OnRemove:Dispatch(self, entity)
end

function Manifest:GetAssignedSignal(componentId)
	return getPool(self, componentId).OnAssign
end

function Manifest:GetRemovedSignal(componentId)
	return getPool(self, componentId).OnRemove
end

function Manifest:GetUpdatedSignal(componentId)
	return getPool(self, componentId).OnUpdate
end

--[[

 Constructs and returns a new view into this entity system instance

 The view iterates entities which have all of the components specified
 by `include` but none of the components specified by the variadic
 argument.

]]
function Manifest:View(included, ...)
	local excluded = select("#", ...) > 0 and { ... } or nil

	for i, componentId in ipairs(included) do
		included[i] = getPool(self, componentId)
	end

	if excluded then
		for i, componentId in ipairs(excluded) do
			excluded[i] = getPool(self, componentId)
		end
	end

	return View.new(included, excluded)
end

getPool = function(manifest, componentId)
	if DEBUG then
		assert(manifest.Pools[componentId], ErrBadComponentId)
	end

	return manifest.Pools[componentId]
end

if DEBUG then
	-- for testing
	Manifest._getPool = getPool
end

return Manifest
