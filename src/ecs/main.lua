--[[

 ecs.lua

 TODO: integrate with luau type system, which wil obviate the need to
 pass identifiers around to specifiy components

 TODO: groups?

]]

local Pool = require(script.Pool)
local Ident = require(script.Parent.core.Ident)
local View = require(script.View)

local DEBUG = true
local ENTITYID_WIDTH = 16
local ENTITYID_MASK = bit32.rshift(0xFFFFFFFF, ENTITYID_WIDTH)
local NULL_ENTITYID = 0
local VERSION_MASK = bit32.lshift(0xFFFFFFFF, 32 - ENTITYID_WIDTH)

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
local generateId = Ident.GenerateRuntime

local Ecs = {}

Ecs.__index = Ecs

function Ecs.new()
	return setmetatable({
		Size = 0,
		Head = NULL_ENTITYID,
		Entities = {},
		Pools = {},
		Component = {}
	}, Ecs)
end


function Ecs:ComponentDef(name, dataType)
	if self.Component[name] then
		return
	end

	local componentId = generateId(name)

	self.Component[name] = componentId
	self.Pools[componentId] = Pool.new(dataType)
end

--[[

 Return a new valid entity identifier

 Entity ids are recycled after they are no longer in use to prevent
 boundless growth of self.Entities.  This is done by implicitly
 maintaining a stack in self.Entities; each element points to the next
 available id.

]]
function Ecs:Create()
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
	local version = bit32.band(identifier, VERSION_MASK)
	local recycled = bit32.bor(entityId, version)

	-- pop the next id off the stack
	self.Head = bit32.band(identifier, ENTITYID_MASK)
	entities[entityId] = recycled

	return recycled
end

--[[

 Destroy the entity, and by extension, all its components

]]
function Ecs:Destroy(entity)
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

 If the entity is alive, return true; otherwise, return false

]]
function Ecs:Valid(entity)
	local id = bit32.band(entity, ENTITYID_MASK)

	return id <= self.Size and self.Entities[id] == entity
end

--[[

 If the entity has no assigned components, return true; otherwise,
 return false

]]
function Ecs:(entity)
  	for _, pool in ipairs(self.Pools) do
		if has(pool, entity) then
			return false
		end
	end

	return true
end

--[[

 If the entity has the component, return true; otherwise, return false

]]
function Ecs:Has(entity, componentId)
	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))
	end

	return not not has(getPool(self, componentId), entity)
end

--[[

 If the entity has the component, return it; otherwise return nil

]]
function Ecs:Get(entity, componentId)
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
function Ecs:Assign(entity, componentId, component)
	local pool = getPool(self, componentId)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))

		assert(not has(pool, entity), ErrAlreadyHas:format(entity))

		-- just basic type checking for now
		assert(pool.Type == typeof(component),
			  ErrBadType:format(pool.Type, typeof(component)))
	end

	local obj = assign(pool, entity, component)

	pool.OnAssign:Dispatch(self, entity)

	return obj
end

--[[

 If the entity already has the component, return it; otherwise, assign
 and return it

]]
function Ecs:GetOrAssign(entity, componentId, component)
	local pool = getPool(self, componentId)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))

		assert(pool.Type == typeof(component),
			  ErrBadType:format(pool.Type, typeof(component)))
	end

	local exists = has(pool, entity)
	local obj = get(pool, entity)

	-- boolean operators won't work here, as obj can be nil if the
	-- component is empty
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
function Ecs:Replace(entity, componentId, component)
	local pool = getPool(self, componentId)
	local index = has(pool, entity)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))

		assert(pool.Type == typeof(component),
			  ErrBadType:format(pool.Type, typeof(component)))

		assert(index, ErrMissing:format(entity))
	end

	if pool.Objects then
		pool[index] = component
	end

	pool.OnUpdate:Dispatch(self, entity)

	return component
end

--[[

 If the entity has the component, replace and return it; otherweise,
 assign and return it

]]
function Ecs:ReplaceOrAssign(entity, componentId, component)
	local pool = getPool(self, componentId)
	local index = has(pool, entity)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))

		assert(pool.Type == typeof(component),
			  ErrBadType:format(pool.Type, typeof(component)))
	end

	if index then
		pool[index] = component

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
function Ecs:Remove(entity, componentId)
	local pool = getPool(self, componentId)

	if DEBUG then
		assert(self:Valid(entity), ErrInvalid:format(entity))

		assert(has(pool, entity), ErrMissing:format(entity))
	end

	destroy(pool, entity)

	pool.OnRemove:Dispatch(self, entity)
end

function Ecs:OnAssign(componentId)
	return getPool(self, componentId).OnAssign
end

function Ecs:OnRemove(componentId)
	return getPool(self, componentId).OnRemove
end

function Ecs:OnUpdate(componentId)
	return getPool(self, componentId).OnUpdate
end

--[[

 Constructs and returns a new view into the data set

 The view iterates entities which have both all of the components
 specified by `include` and none of the components specified by the
 variadic argument.

]]
function Ecs:View(included, ...)
	local excluded = table.pack(...)

	for i, componentId in ipairs(included) do
		included[i] = getPool(self, componentId)
	end

	for i, componentId in ipairs(excluded) do
		excluded[i] = getPool(self, componentId)
	end

	return View(included, excluded)
end

getPool = function(ecs, componentId)
	if DEBUG then
		assert(ecs.Pools[componentId], ErrBadComponentId)
	end

	return ecs.Pools[componentId]
end

return Ecs
