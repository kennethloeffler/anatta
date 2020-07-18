--[[

 Manifest.lua

 TODO: luau types

]]

local Constants = require(script.Parent.Constants)
local Pool = require(script.Parent.Pool)
local Identify = require(script.Parent.Parent.core.Identify)
local Match = require(script.Parent.Match)
local View = require(script.Parent.View)

local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
local ENTITYID_MASK = Constants.ENTITYID_MASK
local NULL_ENTITYID = Constants.NULL_ENTITYID
local STRICT = Constants.STRICT

local ErrAlreadyHas = "entity %08X already has this component type"
local ErrBadComponentId = "invalid component identifier"
local ErrInvalid = "entity %08X either does not exist or it has been destroyed"
local ErrMissing = "entity %08X does not have this component type"
local ErrBadType = "bad component type: expected %s, got %s"

local poolAssign = Pool.assign
local poolClear = Pool.clear
local poolDestroy = Pool.destroy
local poolGet = Pool.get
local poolHas = Pool.has

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

 Register a component type on the manifest and return its handle.

 Handles may be retrieved again via manifest.component (see
 src/core/Identify.lua). For example:

	-- someplace...
	manifest:define("Vector3", "position")

	-- elsewhere...
	local position = manifest.component:named("position")

	manifest:add(manifest:create(), position, Vector3.new(2, 4, 16))

]]
function Manifest:define(dataType, name)
	if STRICT then
		assert(name and type(name) == "string",
			("bad argument #2 (expected string, got %s)"):format(type(name)))
	end

	local id = self.component:generate(name)

	self.pools[id] = Pool.new(name, dataType)

	return id
end

--[[

 Register an observer on the manifest and return its handle.

 Observer handles may be retrieved and used similarly to component
 type handles:

	-- someplace...
	local position = manifest.component:named("position")
	local updatedPositions = manifest:observe("updatedPositions"):updated(position)()

	-- elsewhere...
	local view = manifest:view{ manifest.observer:named("updatedPositions") }

	view:forEachEntity(function(entity)
		...
	end)

 Observer names and component type names may not overlap per-manifest.
 An error will be raised if a name is already in use.

]]
function Manifest:observe(name)
	local id = self.observer:generate(name)
	local pool = Pool.new(name)
	local match = Match.new(self, id, pool)

	self.pools[id] = pool

	return match
end

--[[

 Return a new valid entity identifier.

]]
function Manifest:create()
	local entities = self.entities
	local entityId = self.head

     -- are there any recyclable entity ids?
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

 Return a valid entity identifier equal to the supplied "hint"
 identifier if possible.

 An identifier equal to hint is returned if and only if hint's id is
 not in use by the manifest.

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

 Destroy the entity, and by extension, all its components.

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

	-- push this id onto the stack so that it can be reused, and increment the
	-- identifier's version part to avoid possible collision
	self.entities[entityId] = bit32.bor(
		self.head,
		bit32.lshift(bit32.rshift(entity, ENTITYID_WIDTH) + 1, ENTITYID_WIDTH))

	self.head = entityId
end

--[[

 If the entity identifier corresponds to a valid entity, return true.
 Otherwise, return false.

]]
function Manifest:valid(entity)
	local id = bit32.band(entity, ENTITYID_MASK)

	return (id <= self.size and id ~= NULL_ENTITYID) and
		self.entities[id] == entity
end

--[[

 If the entity has no assigned components, return true.  Otherwise, return
 false.

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

 Pass all the component type handles in use to the given function.

 If an entity is given, pass only the handles of which the entity has a
 component.

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

 If the entity has a component of all of the given types, return true.
 Otherwise, return false.

]]
function Manifest:has(entity, ...)
	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
	end

	for i = 1, select("#", ...) do
		if not poolHas(self:_getPool(select(i, ...)), entity) then
			return false
		end
	end

	return true
end

--[[

 If the entity has a component of any of the given types, return
 true. Otherwise, return false.

]]
function Manifest:any(entity, ...)
	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
	end

	for i = 1, select("#", ...) do
		if poolHas(self:_getPool(select(i, ...)), entity) then
			return true
		end
	end

	return false
end

--[[

 If the entity has a component of the given type, return it. Otherwise, return
 nil.

]]
function Manifest:get(entity, id)
	local pool = self.pools[id]

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
		assert(pool, ErrBadComponentId)
	end

	return poolGet(pool, entity)
end

--[[

 Add the given component to the entity and return it.

 An entity may only have one component of each type at a time. Adding a
 component to an entity which already has one of the same type is undefined.

]]
function Manifest:add(entity, id, component)
	local pool = self.pools[id]

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
		assert(pool, ErrBadComponentId)
		assert(not poolHas(pool, entity), ErrAlreadyHas:format(entity))

		-- just basic type checking for now
		assert(tostring(pool.type) == typeof(component),
			ErrBadType:format(tostring(pool.type), typeof(component)))
	end

	local obj = poolAssign(pool, entity, component)

	pool.onAssign:dispatch(entity)

	return obj
end

--[[

 If the entity has a component of the given type, return it. Otherwise, add the
 given component to the entity and return it.

]]
function Manifest:getOrAdd(entity, id, component)
	local pool = self.pools[id]

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
		assert(pool, ErrBadComponentId)
		assert(tostring(pool.type) == typeof(component),
			ErrBadType:format(tostring(pool.type), typeof(component)))
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

 Replace the entity's component of the given type with the given component.

 Replacing a component that the entity does not have is undefined.

]]
function Manifest:replace(entity, id, component)
	local pool = self.pools[id]

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
		assert(poolHas(pool, entity), ErrMissing:format(entity))
		assert(tostring(pool.type) == typeof(component),
			ErrBadType:format(tostring(pool.type), typeof(component)))
	end

	local index = poolHas(pool, entity)

	if pool.objects then
		pool.objects[index] = component
	end

	pool.onUpdate:dispatch(entity)

	return component
end

--[[

 If the entity has a component of the given type, replace it with the given
 component and return the given component. Otherwise, add the given component to
 the entity and return it.

]]
function Manifest:addOrReplace(entity, id, component)
	local pool = self.pools[id]

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
		assert(pool, ErrBadComponentId)
		assert(tostring(pool.type) == typeof(component),
			ErrBadType:format(tostring(pool.type), typeof(component)))
	end

	local index = poolHas(pool, entity)

	if index then
		if pool.objects then
			pool.objects[index] = component
		end

		pool.onUpdate:dispatch(entity)

		return component
	end

	local obj = poolAssign(pool, entity, component)

	pool.onAssign:dispatch(entity)

	return obj
end

--[[

 Remove a component of the given type from the entity.

 Removing a component which the entity does not have is undefined.

]]
function Manifest:remove(entity, id)
	local pool = self.pools[id]

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
		assert(pool, ErrBadComponentId)
		assert(poolHas(pool, entity), ErrMissing:format(entity))
	end

	pool.onRemove:dispatch(entity)
	poolDestroy(pool, entity)
end

--[[

 If the entity has a component of the given type, remove it. Otherwise, do
 nothing.

]]
function Manifest:removeIfHas(entity, id)
	local pool = self.pools[id]

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
		assert(pool, ErrBadComponentId)
	end

	if poolHas(pool, entity) then
		pool.onRemove:dispatch(entity)
		poolDestroy(pool, entity)
	end
end

--[[

 Return a signal which fires whenever the a component of the given type is
 added to an entity.

]]
function Manifest:added(id)
	local pool = self.pools[id]

	if STRICT then
		assert(pool, ErrBadComponentId)
	end

	return pool.onAssign
end

--[[

 Return a signal which fires whenever a component of the given type is removed
 from an entity.

]]
function Manifest:removed(id)
	local pool = self.pools[id]

	if STRICT then
		assert(pool, ErrBadComponentId)
	end

	return pool.onRemove
end

--[[

 Return a signal which fires whenever a component of the given type is changed
 in some way.

 Currently, this signal only fires upon a call to Manifest:replace.

]]
function Manifest:updated(id)
	local pool = self.pools[id]

	if STRICT then
		assert(pool, ErrBadComponentId)
	end

	return pool.onUpdate
end

--[[

 Clear the underlying storage for components of the given type.

]]
function Manifest:clear(id)
	poolClear(self:_getPool(id))
end

--[[

 Return the number of entities currently in use.

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

 Pass each entity currently in use to func.

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

 Construct and return a view into the manifest.

 The view includes entities which have all components of the types given in
 `included` but no components of the types given in the variadic argument.

]]
function Manifest:view(included, ...)
	local excluded = select("#", ...) > 0 and { ... } or nil

	for i, id in ipairs(included) do
		included[i] = self:_getPool(id)
	end

	if excluded then
		for i, id in ipairs(excluded) do
			excluded[i] = self:_getPool(id)
		end
	end

	return View.new(included, excluded)
end

function Manifest:_getPool(id)
     if STRICT then
		assert(self.pools[id], ErrBadComponentId)
	end

	return self.pools[id]
end

return Manifest
