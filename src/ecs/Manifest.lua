--[[

	Manifest.lua

	TODO: luau types

]]

local Constants = require(script.Parent.Constants)
local Pool = require(script.Parent.Pool)
local Identify = require(script.Parent.Parent.core.Identify)
local Observer = require(script.Parent.Observer)
local View = require(script.Parent.View)

local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
local ENTITYID_MASK = Constants.ENTITYID_MASK
local NULL_ENTITYID = Constants.NULL_ENTITYID
local STRICT = Constants.STRICT

local ErrAlreadyHas = "entity %08X already has this component type"
local ErrBadComponentId = "invalid component identifier"
local ErrInvalid = "entity %08X either does not exist or it has been destroyed"
local ErrMissing = "entity %08X does not have this component type"

local Manifest = {}
Manifest.__index = Manifest

function Manifest.new()
	local ident = Identify.new()

	return setmetatable({
		size = 0,
		nextRecyclable = NULL_ENTITYID,
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
function Manifest:define(typeName, name)
	local id = self.component:generate(name)

	self.pools[id] = Pool.new(name, typeName)

	return id
end

--[[

	Register an observer on the manifest and return its handle.

	Observer handles may be retrieved and used similarly to component type
	handles:

	-- someplace...
	local position = manifest.component:named("position")
	local updatedPositions = manifest:observe("updatedPositions"):updated(position)()

	-- elsewhere...
	local updatedPositions = manifest.observer:named("updatedPositions")

	manifest:view():all(updatedPositions)():forEachEntity(function(entity)
	...
	end)

	Observer names and component type names may not overlap per-manifest.  An
	error will be raised if a name is already in use.

]]
function Manifest:observe(name)
	local id = self.observer:generate(name)
	local pool = Pool.new(name)
	local observer = Observer.new(self, id, pool)

	self.pools[id] = pool

	return observer
end

--[[

	Return a new valid entity identifier.

]]
function Manifest:create()
	local recyclableId = self.nextRecyclable

	if recyclableId == NULL_ENTITYID then
		local entityId = self.size + 1

		self.size = entityId
		self.entities[entityId] = entityId

		return entityId
	else
		local node = self.entities[recyclableId]
		local recycled = bit32.bor(
			recyclableId,
			bit32.lshift(bit32.rshift(node, ENTITYID_WIDTH), ENTITYID_WIDTH))

		self.nextRecyclable = bit32.band(node, ENTITYID_MASK)
		self.entities[recyclableId] = recycled

		return recycled
	end
end

--[[

	Return a valid entity identifier equal to the supplied "hint" identifier if
	possible.

	An identifier equal to hint is returned if and only if hint's id is not in
	use by the manifest.

]]
function Manifest:createFrom(hint)
	local hintId = bit32.band(hint, ENTITYID_MASK)
	local entities = self.entities
	local existingEntity = entities[hintId]
	local existingEntityId = existingEntity and bit32.band(existingEntity, ENTITYID_MASK)

	if not existingEntity then
		for id = self.size + 1, hintId - 1  do
			entities[id] = self.nextRecyclable
			self.nextRecyclable = id
		end

		entities[hintId] = hint

		return hint
	elseif existingEntityId == hintId then
		return self:create()
	else
		local nextRecyclable = self.nextRecyclable

		while nextRecyclable ~= hintId do
			nextRecyclable = bit32.band(entities[nextRecyclable], ENTITYID_MASK)
		end

		entities[nextRecyclable] = bit32.bor(
			existingEntityId,
			bit32.lshift(bit32.rshift(entities[nextRecyclable], ENTITYID_WIDTH), ENTITYID_WIDTH))
		entities[hintId] = hint

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
		if pool:has(entity) then
			pool.onRemove:dispatch(entity)
			pool:destroy(entity)
		end
	end

	-- push this id onto the stack so that it can be recycled, and increment
	-- the identifier's version to avoid possible collision
	self.entities[entityId] = bit32.bor(
		self.nextRecyclable,
		bit32.lshift(bit32.rshift(entity, ENTITYID_WIDTH) + 1, ENTITYID_WIDTH))

	self.nextRecyclable = entityId
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
		if pool:has(entity) then
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
			if pool:has(entity) then
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
		if not self.pools[select(i, ...)]:has(entity) then
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
		if self.pools[select(i, ...)]:has(entity) then
			return true
		end
	end

	return false
end

--[[

	If the entity has a component of the given type, return it. Otherwise,
	return nil.

]]
function Manifest:get(entity, id)
	local pool = self.pools[id]

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
		assert(pool, ErrBadComponentId)
	end

	return pool:get(entity)
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
		assert(not pool:has(entity), ErrAlreadyHas:format(entity))
	end

	local obj = pool:assign(entity, component)

	pool.onAssign:dispatch(entity)

	return obj
end

--[[

	If the entity has a component of the given type, return it. Otherwise, add
	the given component to the entity and return it.

]]
function Manifest:getOrAdd(entity, id, component)
	local pool = self.pools[id]

	if STRICT then
		assert(self:valid(entity), ErrInvalid:format(entity))
		assert(pool, ErrBadComponentId)
	end

	local exists = pool:has(entity)
	local obj = pool:get(entity)

	if exists then
		return obj
	else
		obj = pool:assign(entity, component)

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
		assert(pool:has(entity), ErrMissing:format(entity))
	end

	local index = pool:has(entity)

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
	end

	local index = pool:has(entity)

	if index then
		if pool.objects then
			pool.objects[index] = component
		end

		pool.onUpdate:dispatch(entity)

		return component
	end

	local obj = pool:assign(entity, component)

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
		assert(pool:has(entity), ErrMissing:format(entity))
	end

	pool.onRemove:dispatch(entity)
	pool:destroy(entity)
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

	if pool:has(entity) then
		pool.onRemove:dispatch(entity)
		pool:destroy(entity)
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

	Return a signal which fires whenever a component of the given type is
	removed from an entity.

]]
function Manifest:removed(id)
	local pool = self.pools[id]

	if STRICT then
		assert(pool, ErrBadComponentId)
	end

	return pool.onRemove
end

--[[

	Return a signal which fires whenever a component of the given type is
	changed in some way.

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
	self:_getPool(id):clear()
end

--[[

	Return the number of entities currently in use.

]]
function Manifest:numEntities()
	local entities = self.entities
	local curr = self.nextRecyclable
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
	if self.nextRecyclable == NULL_ENTITYID then
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

	Construct and return a view into the manifest (see ./View.lua).

]]
function Manifest:view()
	return View.new(self)
end

function Manifest:_getPool(id)
     if STRICT then
		assert(self.pools[id], ErrBadComponentId)
	end

	return self.pools[id]
end

return Manifest
