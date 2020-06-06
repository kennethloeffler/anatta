--[[

 Manifest.lua

 TODO: luau types

 TODO: groups?

]]

local Constants = require(script.Parent.Constants)
local Pool = require(script.Parent.Pool)
local Identify = require(script.Parent.Parent.core.Identify)
local View = require(script.Parent.View)

local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
local ENTITYID_MASK = Constants.ENTITYID_MASK
local NULL_ENTITYID = Constants.NULL_ENTITYID
local STRICT = Constants.STRICT

local ErrAlreadyHas = "entity %06X already has this component"
local ErrBadComponentId = "invalid component identifier"
local ErrInvalid = "entity %06X either does not exist or it has been destroyed"
local ErrMissing = "entity %06X does not have this component"
local ErrBadType = "bad component data type: expected %s, got %s"

local poolAssign = Pool.assign
local poolClear = Pool.clear
local poolDestroy = Pool.destroy
local poolGet = Pool.get
local poolHas = Pool.has

local getPool

local Manifest = {}
Manifest.__index = Manifest

function Manifest.new()
	return setmetatable({
		size = 0,
		head = NULL_ENTITYID,
		entities = {},
		pools = {},
		component = Identify.new("__component"),
		observer = Identify.new()
	}, Manifest)
end

function Manifest:define(name, dataType)
	local id = self.component:generate(name)

	self.pools[id] = Pool.new(dataType)

	return id
end

function Manifest:observer(name, match)
	local observerId = self.observer:generate(name)
	local pool = Pool.new("number")

	self.pools[observerId] = pool
	match:_connect(self, pool)

	return observerId
end

--[[

 Return a new valid entity identifier

 Entity ids (which are really just an indices into the entities array)
 are recycled after they are no longer in use to prevent boundless
 growth of the entities array.  This is done by:

 1.  maintaining an implicit stack in the array, where each element
 "points" to the next recyclable id, or to the null id if there are
 none, and;

 2.  keeping an incrementing "version" in the high bits of the
 identifier (the entity id resides in the low bits).

]]
function Manifest:create()
	local entities = self.entities
	local entityId = self.head

	if entityId == NULL_ENTITYID then
		entityId = self.size + 1
		self.size = entityId
		entities[entityId] = entityId

		return entityId
	end

	local identifier = entities[entityId]
	local version = bit32.lshift(bit32.rshift(identifier, ENTITYID_WIDTH), ENTITYID_WIDTH)
	local recycled = bit32.bor(entityId, version)

	self.head = bit32.band(identifier, ENTITYID_MASK)
	entities[entityId] = recycled

	return recycled
end

--[[

 Return a valid entity identifier equal to the one provided if
 possible

]]
function Manifest:createFrom(hint)
	local entityId = bit32.band(hint, ENTITYID_MASK)
	local entities = self.entities
	local entity = hint
	local currEntity = entities[entityId]
	local currEntityId = currEntity and bit32.band(currEntity, ENTITYID_MASK)

	if not currEntity then
		for i = self.size + 1, entityId - 1  do
			entities[i] = self.head
			self.head = i
		end

		entities[entityId] = entity
	elseif currEntityId == entityId then
		entity = self:create()
	else
		local currId = self.head

		while currId ~= entityId do
			currId = bit32.band(entities[currId], ENTITYID_MASK)
		end

		entities[currId] = bit32.bor(
			currEntityId,
			bit32.lshift(bit32.rshift(entities[currId], ENTITYID_WIDTH), ENTITYID_WIDTH))
		entities[entityId] = entity
	end

	return entity
end

--[[

 Destroy the entity, and by extension, all its components

]]
function Manifest:destroy(entity)
	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
	end

	local entityId = bit32.band(entity, ENTITYID_MASK)

	for _, pool in ipairs(self.pools) do
		if poolHas(pool, entity) then
			pool.onRemove:dispatch(entity)
			poolDestroy(pool, entity)
		end
	end

	-- push this id onto the stack so that it can be reused, and
	-- increment the identifier's version part in order to avoid
	-- possible collision
	self.entities[entityId] = bit32.bor(
		self.head,
		bit32.lshift(bit32.rshift(entity, ENTITYID_WIDTH) + 1, ENTITYID_WIDTH))

	self.head = entityId
end

--[[

 If the entity identifier corresponds to a valid entity, return true;
 otherwise return false

]]
function Manifest:valid(entity)
	local id = bit32.band(entity, ENTITYID_MASK)

	return (id <= self.size and id ~= NULL_ENTITYID) and
		self.entities[id] == entity
end

--[[

 If the entity has no assigned components, return true; otherwise
 return false

]]
function Manifest:stub(entity)
  	for _, pool in ipairs(self.pools) do
		if poolHas(pool, entity) then
			return false
		end
	end

	return true
end

function Manifest:visit(func, entity)
	if entity then
		for id, pool in ipairs(self.pools) do
			if poolHas(pool, entity) then
				func(id)
			end
		end
	else
		for id in ipairs(self.pools) do
			func(id)
		end
	end
end

--[[

 If the entity has the component, return true; otherwise return false

]]
function Manifest:has(entity, id)
	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
	end

	return not not poolHas(getPool(self, id), entity)
end

--[[

 If the entity has the component, return it; otherwise return nil

]]
function Manifest:get(entity, id)
	local pool = getPool(self, id)

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
	end

	return poolGet(pool, entity)
end

--[[

 Assign a component to the entity

 Assigning to an entity that already has the component is undefined.

]]
function Manifest:assign(entity, id, component)
	local pool = getPool(self, id)

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))

		assert(not poolHas(pool, entity), ErrAlreadyHas:format(entity))

		-- just basic type checking for now
		assert(pool.type == nil or pool.type == typeof(component),
		       ErrBadType:format(pool.type or "nil", typeof(component)))
	end

	local obj = poolAssign(pool, entity, component)

	pool.onAssign:dispatch(entity)

	return obj
end

--[[

 If the entity already has the component, return it; otherwise assign
 and return it

]]
function Manifest:getOrAssign(entity, id, component)
	local pool = getPool(self, id)

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))

		assert(pool.type == nil or pool.type == typeof(component),
		       ErrBadType:format(pool.type or "nil", typeof(component)))
	end

	local exists = poolHas(pool, entity)
	local obj = poolGet(pool, entity)

	-- boolean operators alone won't work here, because obj can be
	-- equal to nil if the component is empty (i.e. it's a "flag"
	-- component)
	if exists then
		return obj
	else
		obj = poolAssign(pool, entity, component)

		pool.onAssign:dispatch(entity)

		return obj
	end
end

--[[

 Replace the component assigned to the entity with a new one

 Replacing a component which is not assigned to the entity is
 undefined.

]]
function Manifest:replace(entity, id, component)
	local pool = getPool(self, id)
	local index = poolHas(pool, entity)

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))

		assert(pool.type == nil or pool.type == typeof(component),
		       ErrBadType:format(pool.type or "", typeof(component)))

		assert(index, ErrMissing:format(entity))
	end

	if pool.objects then
		pool.objects[index] = component
	end

	pool.onReplace:dispatch(entity)

	return component
end

--[[

 If the entity has the component, replace and return it; otherweise,
 assign and return it

]]
function Manifest:assignOrReplace(entity, id, component)
	local pool = getPool(self, id)
	local index = poolHas(pool, entity)

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))

		assert(pool.type == nil or pool.type == typeof(component),
		       ErrBadType:format(pool.type or "", typeof(component)))
	end

	if index then
		if pool.objects then
			pool.objects[index] = component
		end

		pool.onReplace:dispatch(entity)

		return component
	end

	local obj = poolAssign(pool, entity, component)

	pool.onAssign:dispatch(entity)

	return obj
end

--[[

 Remove the component from the entity

 Removing a component which is not assigned to the entity is
 undefined.

]]
function Manifest:remove(entity, id)
	local pool = getPool(self, id)

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))

		assert(poolHas(pool, entity), ErrMissing:format(entity))
	end

	poolDestroy(pool, entity)

	pool.onRemove:dispatch(entity)
end

function Manifest:removeIfHas(entity, id)
	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
	end

	local pool = getPool(self, id)

	if poolHas(pool, entity) then
		poolDestroy(pool, entity)
	end
end

function Manifest:assigned(id)
	return getPool(self, id).onAssign
end

function Manifest:removed(id)
	return getPool(self, id).onRemove
end

function Manifest:replaced(id)
	return getPool(self, id).onReplace
end

function Manifest:clear(id)
	poolClear(getPool(self, id))
end

function Manifest:numEntities()
	local entities = self.entities
	local curr = self.head
	local size = self.size

	while curr ~= NULL_ENTITYID do
		size = size - 1
		curr = bit32.band(entities[curr], ENTITYID_MASK)
	end

	return size
end

function Manifest:forEach(func)
	if self.head == NULL_ENTITYID then
		for _, entity in ipairs(self.entities) do
			func(entity)
		end
	else
		for id, entity in ipairs(self.entities) do
			if bit32.band(entity, ENTITYID_MASK) == id then
				func(entity)
			end
		end
	end
end

--[[

 Constructs and returns a view into this manifest

 The view iterates entities which have all of the components specified
 by `include` but none of the components specified by the variadic
 argument.

]]
function Manifest:view(included, ...)
	local excluded = select("#", ...) > 0 and { ... } or nil

	for i, id in ipairs(included) do
		included[i] = getPool(self, id)
	end

	if excluded then
		for i, id in ipairs(excluded) do
			excluded[i] = getPool(self, id)
		end
	end

	return View.new(included, excluded)
end

getPool = function(manifest, id)
	if STRICT then
		assert(manifest.pools[id], ErrBadComponentId)
	end

	return manifest.pools[id]
end

Manifest._getPool = getPool

return Manifest
