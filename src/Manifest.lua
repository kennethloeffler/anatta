--[[

	Manifest.lua

	TODO: luau types

]]

local Constraint = require(script.Parent.Constraint)
local Constants = require(script.Parent.Constants)
local Pool = require(script.Parent.Pool)
local Identify = require(script.Parent.core.Identify)

local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
local ENTITYID_MASK = Constants.ENTITYID_MASK
local NULL_ENTITYID = Constants.NULL_ENTITYID

local Manifest = {}
Manifest.__index = Manifest

function Manifest.new()
	local ident = Identify.new()

	return setmetatable({
		size = 0,
		nextRecyclable = NULL_ENTITYID,
		entities = {},
		pools = {},
		contexts = {},
		ident = ident,
	}, Manifest)
end

function Manifest:T(name)
	local id = self.ident:named(name)

	return id, self:context(id)
end

--[[

	Register a component type and return its handle.

	Handles may be retrieved again via manifest:T:

	-- someplace...
	manifest:define("Vector3", "position")

	-- elsewhere...
	local position = manifest:T "position"

	manifest:add(manifest:create(), position, Vector3.new(2, 4, 16))

]]
function Manifest:define(typeName, name)
	local id = self.ident:generate(name)

	self.pools[id] = Pool.new(name, typeName)

	return id
end

--[[

	Return a new valid entity identifier.

]]
function Manifest:create()
	if self.nextRecyclable == NULL_ENTITYID then
		self.size += 1
		self.entities[self.size] = self.size

		return self.size
	else
		local node = self.entities[self.nextRecyclable]
		local recycled = bit32.bor(
			self.nextRecyclable,
			bit32.lshift(bit32.rshift(node, ENTITYID_WIDTH), ENTITYID_WIDTH))

		self.entities[self.nextRecyclable] = recycled
		self.nextRecyclable = bit32.band(node, ENTITYID_MASK)

		return recycled
	end
end

--[[

	If possible, return a new valid entity identifier equal to the given entity
	identifier.

	An identifier equal to the given identifier is returned if and only if the
	given identifier's id part is not in use by the manifest.  Otherwise, a new
	identifier created via Manifest:create() is returned.

]]
function Manifest:createFrom(entity)
	local entityId = bit32.band(entity, ENTITYID_MASK)
	local existingEntityId = bit32.band(
		self.entities[entityId] or NULL_ENTITYID,
		ENTITYID_MASK
	)

	if existingEntityId == NULL_ENTITYID then
		for id = self.size + 1, entityId - 1  do
			self.entities[id] = self.nextRecyclable
			self.nextRecyclable = id
		end

		self.entities[entityId] = entity

		return entity
	elseif existingEntityId == entityId then
		return self:create()
	else
		local curr = self.nextRecyclable

		if curr == entityId then
			self.nextRecyclable = bit32.band(
				self.entities[entityId],
				ENTITYID_MASK)
			self.entities[entityId] = entity

			return entity
		end

		local last

		while curr ~= entityId do
			last = curr
			curr = bit32.band(self.entities[curr], ENTITYID_MASK)
		end

		self.entities[last] = bit32.bor(
			bit32.band(self.entities[entityId], ENTITYID_MASK),
			bit32.lshift(
				bit32.rshift(self.entities[last], ENTITYID_WIDTH),
				ENTITYID_WIDTH))

		self.entities[entityId] = entity

		return entity
	end
end

--[[

	Destroy the entity, and by extension, all its components.

]]
function Manifest:destroy(entity)
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
	for i = 1, select("#", ...) do
		if not self.pools[select(i, ...)]:has(entity) then
			return false
		end
	end

	return true
end

--[[

	If the entity has a component of any of the given types, return true.
	Otherwise, return false.

]]
function Manifest:any(entity, ...)
	for i = 1, select("#", ...) do
		if self.pools[select(i, ...)]:has(entity) then
			return true
		end
	end

	return false
end

--[[

	If the entity has a component of the given type, return the component
	instance.  Otherwise, return nil.

]]
function Manifest:get(entity, id)
	return self.pools[id]:get(entity)
end

function Manifest:maybeGet(entity, id)
	local pool = self.pools[id]

	if pool:has(entity) then
		return pool:get(entity)
	end
end

function Manifest:multiGet(entity, output, ...)
	for i = 1, select("#", ...) do
		local id = select(i, ...)

		output[i] = self.pools[id]:get(entity, select(i, ...))
	end

	return unpack(output)
end

--[[

	Add the given component to the entity and return the new component
	instance.

	An entity may only have one component from each type at a time. Adding a
	component to an entity that already has a component of the same type is
	undefined.

]]
function Manifest:add(entity, id, component)
	local pool = self.pools[id]
	local obj = pool:assign(entity, component)

	pool.onAdd:dispatch(entity)

	return obj
end

function Manifest:maybeAdd(entity, id, component)
	local pool = self.pools[id]

	if pool:has(entity) then
		return
	end

	local obj = pool:assign(entity, component)

	pool.onAdd:dispatch(entity)

	return obj
end

function Manifest:multiAdd(entity, ...)
	local num = select("#", ...)

	for i = 1, num, 2 do
		self:add(entity, select(i, ...), select(i + 1, ...))
	end

	return entity
end

function Manifest:assign(entities, id, component, ...)
	if component and type(component) == "function" then
		for _, entity in ipairs(entities) do
			self:add(entity, id, component(...))
		end
	elseif component then
		for _, entity in ipairs(entities) do
			self:add(entity, id, component)
		end
	else
		for _, entity in ipairs(entities) do
			self:remove(entity, id)
		end
	end
end

--[[

	If the entity has a component of the given type, return the component
	instance.  Otherwise, add the given component to the entity and return the
	new component.

]]
function Manifest:getOrAdd(entity, id, component)
	local pool = self.pools[id]
	local exists = pool:has(entity)
	local obj = pool:get(entity)

	if exists then
		return obj
	else
		obj = pool:assign(entity, component)
		pool.onAdd:dispatch(entity)

		return obj
	end
end

--[[

	Replace the entity's component of the given type with the given component.

	Replacing a component that the entity does not have is undefined.

]]
function Manifest:replace(entity, id, component)
	local pool = self.pools[id]

	pool.objects[pool:has(entity)] = component
	pool.onUpdate:dispatch(entity)

	return component
end

--[[

	If the entity has a component of the given type, replace it with the given
	component and return the new component instance. Otherwise, add the given
	component to the entity and return the new component instance.

]]
function Manifest:addOrReplace(entity, id, component)
	local pool = self.pools[id]
	local index = pool:has(entity)

	if index then
		pool.objects[index] = component
		pool.onUpdate:dispatch(entity)

		return component
	end

	local obj = pool:assign(entity, component)
	pool.onAdd:dispatch(entity)

	return obj
end

--[[

	Remove a component of the given type from the entity.

	Removing a component which the entity does not have is undefined.

]]
function Manifest:remove(entity, id)
	local pool = self.pools[id]

	pool.onRemove:dispatch(entity)
	pool:destroy(entity)
end

--[[

	If the entity has a component of the given type, remove it.  Otherwise, do
	nothing.

]]
function Manifest:maybeRemove(entity, id)
	local pool = self.pools[id]

	if pool:has(entity) then
		pool.onRemove:dispatch(entity)
		pool:destroy(entity)

		return true
	end

	return false
end

--[[

	Return a signal which fires just after the component of the given type is
	added to an entity.

]]
function Manifest:onAdded(id)
	return self.pools[id].onAdd
end

--[[

	Return a signal which fires whenever a component of the given type is
	removed from an entity.

]]
function Manifest:onRemoved(id)
	return self.pools[id].onRemove
end

--[[

	Return a signal which fires whenever a component of the given type is
	changed in some way.

]]
function Manifest:onUpdated(id)
	return self.pools[id].onUpdate
end

--[[

	Return the number of entities currently in use.

]]
function Manifest:numEntities()
	local curr = self.nextRecyclable
	local num = self.size

	while curr ~= NULL_ENTITYID do
		num -= 1
		curr = bit32.band(self.entities[curr], ENTITYID_MASK)
	end

	return num
end

--[[

	Pass each entity currently in use to the given function.

]]
function Manifest:each(func)
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

function Manifest:all(...)
	return Constraint.new(self, { ... })
end

function Manifest:except(...)
	return Constraint.new(self, nil, { ... })
end

function Manifest:updated(...)
	return Constraint.new(self, nil, nil, { ... })
end

--[[

	Inject a context variable into the manifest.

]]
function Manifest:context(context, value)
	if value then
		assert(self.contexts[context] == nil, ("context %s already set")
			:format(context))

		self.contexts[context] = value
	end

	return self.contexts[context]
end

function Manifest:poolSize(id)
	return self.pools[id].size
end

function Manifest:_getPool(id)
	return self.pools[id]
end

return Manifest
