--[[

 Manifest.lua

 TODO: luau types

]]

local Constants = require(script.Parent.Constants)
local Pool = require(script.Parent.Pool)
local Identify = require(script.Parent.Parent.core.Identify)
local View = require(script.Parent.View)

local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
local ENTITYID_MASK = Constants.ENTITYID_MASK
local NULL_ENTITYID = Constants.NULL_ENTITYID
local STRICT = Constants.STRICT

local ErrAlreadyHas = "entity %06X already has this component type"
local ErrBadComponentId = "invalid component identifier"
local ErrInvalid = "entity %06X either does not exist or it has been destroyed"
local ErrMissing = "entity %06X does not have this component type"
local ErrBadType = "bad component value type: expected %s, got %s"

local poolAssign = Pool.assign
local poolClear = Pool.clear
local poolDestroy = Pool.destroy
local poolGet = Pool.get
local poolHas = Pool.has

local getPool

local Manifest = {}
Manifest.__index = Manifest

function Manifest.new()
	local ident = Identify.new()

	return setmetatable({
		size = 0,
		head = NULL_ENTITYID,
		entities = {},
		pools = {},
		component = ident,
		observer = ident
	}, Manifest)
end

--[[

 Register a component type for the manifest and return its handle

 Handles may be retrieved again via manifest.component (see
 src/core/Identify.lua). Example:

	-- someplace...
	manifest:define("position", "Vector3")

	-- elsewhere...
	local position = manifest.component:named("position")

	manifest:assign(manifest:create(), position, Vector3.new(2, 4, 16))

 This approach was chosen over string literals because it makes the
 relationship between a component type and the manifest which manages
 it more explicit. Also, stashing component type handles at the
 beginning of each system makes it obvious at a glance which component
 types a given system operates on.

]]
function Manifest:define(name, dataType)
	local id = self.component:generate(name)

	self.pools[id] = Pool.new(name, dataType)

	return id
end

--[[

 Register an observer on the manifest and return its handle

 Observer handles may be retrieved and used similarly to component
 type handles:

	-- someplace...
	local position = manifest:component:named("position")
	local updatedPositions = manifest:observe("updatedPositions", match:updated(position))

	-- elsewhere...
	local view = manifest:view{ manifest.observer:named("updatedPositions") }

	view:forEachEntity(function(entity)
		...
	end)

 Observer names and component type names may not overlap per-manifest;
 an error will be raised if a name is already in use. Also note that
 an observer's associated pool is number-valued. This is an
 implementation detail - these values must not be modified and there
 should be no reason to inspect them.

]]
function Manifest:observe(name, match)
	local id = self.observer:generate(name)
	local pool = Pool.new(name, "number")

	self.pools[id] = pool
	match:_connect(self, pool)

	return id
end

--[[

 Return a new valid entity identifier

 Each entity identifier (for our purposes, a 32-bit integer) is
 composed of an id part in the low bits and a version part in the high
 bits. The width of these fields is specified by the constant
 ENTITYID_WIDTH.

 Entity ids are recycled after destruction to prevent boundless growth
 of the entities array.  This is done by maintaining an implicit stack
 in the array, where each element "points" to the next recyclable id,
 or to the null id if there are none.

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
	local recycled = bit32.bor(
		entityId,
		bit32.lshift(bit32.rshift(identifier, ENTITYID_WIDTH), ENTITYID_WIDTH))

	self.head = bit32.band(identifier, ENTITYID_MASK)
	entities[entityId] = recycled

	return recycled
end

--[[

 Return a valid entity identifier equal to the one provided if
 possible

 An identifier equal to hint is returned if and only if the hint's id
 is not in use by the manifest.

]]
function Manifest:createFrom(hint)
	local entityId = bit32.band(hint, ENTITYID_MASK)
	local entities = self.entities
	local currEntity = entities[entityId]
	local currEntityId = currEntity and bit32.band(currEntity, ENTITYID_MASK)

	if not currEntity then
		for i = self.size + 1, entityId - 1  do
			entities[i] = self.head
			self.head = i
		end

		entities[entityId] = hint

		return hint
	elseif currEntityId == entityId then
		return self:create()
	else
		local currId = self.head

		while currId ~= entityId do
			currId = bit32.band(entities[currId], ENTITYID_MASK)
		end

		entities[currId] = bit32.bor(
			currEntityId,
			bit32.lshift(bit32.rshift(entities[currId], ENTITYID_WIDTH), ENTITYID_WIDTH))

		entities[entityId] = hint

		return hint
	end
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
	-- increment the identifier's version part to avoid possible
	-- collision
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

 If the entity has no assigned component types, return true; otherwise
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

--[[

 Passes all the component types handles to the supplied function

 If an entity is supplied, only the component type handles assigned to
 the entity are passed

]]
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

 If the entity has all of the specified component types, return true;
 otherwise return false

]]
function Manifest:has(entity, ...)
	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
	end

	for i = 1, select("#", ...) do
		if not poolHas(getPool(self, select(i, ...)), entity) then
			return false
		end
	end

	return true
end

--[[

 If the entity has any of the specified component types, return true;
 otherwise return false

]]
function Manifest:any(entity, ...)
	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
	end

	for i = 1, select("#", ...) do
		if poolHas(getPool(self, select(i, ...)), entity) then
			return true
		end
	end

	return false
end

--[[

 If the entity has the component type, return its value; otherwise
 return nil

]]
function Manifest:get(entity, id)
	local pool = getPool(self, id)

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
	end

	return poolGet(pool, entity)
end

--[[

 Assign the component type to the entity and return its value

 Assigning a component type to an entity which already has it is
 undefined.

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

 If the entity has the component type, return its value; otherwise
 assign it and return its value

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

	if exists then
		return obj
	else
		obj = poolAssign(pool, entity, component)

		pool.onAssign:dispatch(entity)

		return obj
	end
end

--[[

 Replace the component type's currently assigned value on the entity

 Replacing a component type which is not assigned to the entity is
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

 If the entity has the component type, replace and return its value;
 otherwise assign and return its value

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

 Remove the component type from the entity

 Removing a component type from an entity which does not have it is
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

--[[

 If the entity has the component type, remove it; otherwise, do
 nothing

]]
function Manifest:removeIfHas(entity, id)
	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
	end

	local pool = getPool(self, id)

	if poolHas(pool, entity) then
		poolDestroy(pool, entity)
	end
end

--[[

 Return a signal which fires whenever the component type is assigned to
 an entity

]]
function Manifest:assigned(id)
	return getPool(self, id).onAssign
end

--[[

 Return a signal which fires whenever the component type is removed from
 an entity

]]
function Manifest:removed(id)
	return getPool(self, id).onRemove
end

--[[

 Return a signal which fires whenever the component type's value on an
 entity is replaced

]]
function Manifest:replaced(id)
	return getPool(self, id).onReplace
end

--[[

 Clear the underlying storage for the component type

]]
function Manifest:clear(id)
	poolClear(getPool(self, id))
end

--[[

 Return the total number of entities currently in use by the manifest

]]
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

--[[

 Apply func to each entity in use by the manifest

]]
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

 Constructs and returns a view into the manifest

 The view iterates entities which have all of the component types
 specified by `included` but none of the component types specified by
 the variadic argument.

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
