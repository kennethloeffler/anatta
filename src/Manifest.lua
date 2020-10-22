--[[

	Manifest.lua

]]

local Constraint = require(script.Parent.Constraint)
local Core = require(script.Parent.Core)
local Pool = require(script.Parent.Pool)

local Constants = Core.Constants
local Identity = Core.Identity
local Signal = Core.Signal
local TypeDef = Core.TypeDef

local ENTITYID_MASK = Constants.ENTITYID_MASK
local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
local NULL_ENTITYID = Constants.NULL_ENTITYID

local Manifest = {}
Manifest.__index = Manifest

local function loadDefinitions(module, manifest)
	local definitions = require(module)(TypeDef, manifest)

	for name, definition in pairs(definitions) do
		manifest:define(name, definition.type, definition.constructor)
	end
end

function Manifest.new()
	local ident = Identity.new()

	return setmetatable({
		contexts = {},
		entities = {},
		ident = ident,
		nextRecyclable = NULL_ENTITYID,
		none = Constants.NONE,
		nullEntity = NULL_ENTITYID,
		pools = {},
		size = 0,
		t = TypeDef
	}, Manifest)
end

function Manifest:load(projectRoot)
	local components = projectRoot:FindFirstChild("Components")
		or projectRoot:FindFirstChild("components")

	assert(components, string.format("no component folder found in %s", projectRoot:GetFullName()))

	self.ident:tryLoad(projectRoot)

	if components:IsA("ModuleScript") then
		loadDefinitions(components, self)
	end

	for _, instance in ipairs(components:GetDescendants()) do
		if instance:IsA("ModuleScript") then
			loadDefinitions(instance, self)
		end
	end
end

function Manifest:T(name)
	local id = self.ident:named(name)

	return id, self.contexts[string.format("constructor_%s", id)]
end

--[[

	Register a component type and return its identifier.

	Identifiers may be retrieved via manifest:T:

	-- someplace...
	manifest:define("Vector3", "position")

	-- elsewhere...
	local position = manifest:T "position"

	manifest:add(manifest:create(), position, Vector3.new(2, 4, 16))

]]
function Manifest:define(name, typeDef, constructor)
	local id = self.ident.lookup[name] or self.ident:generate(name)
	local pool = Pool.new(name, typeDef)
	local type = typeDef.type

	if constructor ~= nil then
		self:inject(string.format("constructor_%s", id), constructor)
	end

	if type == "Instance" or type == "instance" or type == "instanceOf" or type == "instanceIsA" then
		pool.onRemove:connect(function(entity)
			pool:get(entity):Destroy()
		end)
	elseif next(typeDef.instanceFields) ~= nil then
		pool.onRemove:connect(function(entity)
			local component = pool:get(entity)

			for fieldName in pairs(typeDef.instanceFields) do
				component[fieldName]:Destroy()
			end
		end)
	end

	self.pools[id] = pool
	return id, constructor
end

--[[

	Return a new valid entity.

]]
function Manifest:create()
	if self.nextRecyclable == NULL_ENTITYID then
		-- no entityIds to recycle
		local newEntity = self.size + 1
		self.size = newEntity
		self.entities[newEntity] = newEntity

		return newEntity
	else
		-- there is at least one recyclable entityId; pop the free list
		local entities = self.entities
		local nextRecyclable = self.nextRecyclable
		local node = entities[nextRecyclable]
		local recycledEntity = bit32.bor(
			nextRecyclable,
			bit32.lshift(bit32.rshift(node, ENTITYID_WIDTH), ENTITYID_WIDTH))

		entities[nextRecyclable] = recycledEntity
		self.nextRecyclable = bit32.band(node, ENTITYID_MASK)

		return recycledEntity
	end
end

--[[

	If possible, return a new valid entity identifier equal to the given entity
	identifier.

	An identifier equal to the given identifier is returned if and only if the given
	identifier's id part is not in use by the manifest.  Otherwise, a new identifier
	created via Manifest:create() is returned.

]]
function Manifest:createFrom(entity)
	local entityId = bit32.band(entity, ENTITYID_MASK)
	local entities = self.entities
	local existingEntityId = bit32.band(
		self.entities[entityId] or NULL_ENTITYID,
		ENTITYID_MASK)

	if existingEntityId == NULL_ENTITYID then
		-- the given identifier's entityId is out of range; create the entities in
		-- between size and entityId and add them to the free list
		local nextRecyclable = self.nextRecyclable

		for id = self.size + 1, entityId - 1  do
			entities[id] = nextRecyclable
			nextRecyclable = id
		end

		self.size = entityId
		self.nextRecyclable = nextRecyclable
		entities[entityId] = entity

		return entity
	elseif existingEntityId == entityId then
		-- the entityId is in use; create a new entity
		return self:create()
	else
		-- the entityId is in the free list; find it and remove it
		local nextRecyclable = self.nextRecyclable

		if nextRecyclable == entityId then
			-- entityId is at the head of the list; don't need to iterate, just need to
			-- pop
			self.nextRecyclable = bit32.band(entities[entityId], ENTITYID_MASK)
			entities[entityId] = entity

			return entity
		end

		local lastRecyclable

		-- find the entityId in the free list
		while nextRecyclable ~= entityId do
			lastRecyclable = nextRecyclable
			nextRecyclable = bit32.band(self.entities[nextRecyclable], ENTITYID_MASK)
		end

		-- make the previous element point to the next
		entities[lastRecyclable] = bit32.bor(
			bit32.band(entities[entityId], ENTITYID_MASK),
			bit32.lshift(
				bit32.rshift(entities[lastRecyclable], ENTITYID_WIDTH),
				ENTITYID_WIDTH))

		entities[entityId] = entity

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
			pool.onRemove:dispatch(entity, pool:get(entity))
			pool:destroy(entity)
		end
	end

	-- push this id onto the free list so that it can be recycled, and increment the
	-- identifier's version to avoid possible collision
	self.entities[entityId] = bit32.bor(
		self.nextRecyclable,
		bit32.lshift(bit32.rshift(entity, ENTITYID_WIDTH) + 1, ENTITYID_WIDTH))

	self.nextRecyclable = entityId
end

--[[

	If the entity identifier corresponds to a valid entity, return true.  Otherwise,
	return false.

]]
function Manifest:valid(entity)
	local id = bit32.band(entity, ENTITYID_MASK)

	return (id <= self.size and id ~= NULL_ENTITYID) and self.entities[id] == entity
end

--[[

	If the entity has no assigned components, return true.  Otherwise, return false.

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

	Pass all the component type identifiers in use to the given function.

	If an entity is given, pass only the component ids of which the entity has a
	component.

]]
function Manifest:visit(func, entity)
	if entity ~= nil then
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

	If the entity has a component of all of the given types, return true.  Otherwise,
	return false.

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

	If the entity has a component of any of the given types, return true.  Otherwise,
	return false.

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

	Get and return a component on the entity.

	Strict will throw if the entity does not have a component of the given type.

]]
function Manifest:get(entity, id)
	return self.pools[id]:get(entity)
end

--[[

	If the entity has the component, return the component.  Otherwise, do nothing.

]]
function Manifest:tryGet(entity, id)
	local pool = self.pools[id]

	if pool:has(entity) then
		return pool:get(entity)
	end
end

--[[

	Get and return all of the components of the given types on the entity.

]]
function Manifest:multiGet(entity, output, ...)
	for i = 1, select("#", ...) do
		local id = select(i, ...)

		output[i] = self.pools[id]:get(entity, select(i, ...))
	end

	return unpack(output)
end

--[[

	Add the component to the entity and return the component.

	An entity may only have one component of each type at a time.  Strict will throw upon
	an attempt to add multiple components of the same type to an entity.

]]
function Manifest:add(entity, id, component)
	local pool = self.pools[id]

	pool:assign(entity, component)
	pool.onAdd:dispatch(entity, component)

	return component
end

--[[

	If the entity does not have the component, add it and return the component.
	Otherwise, do nothing.

]]
function Manifest:tryAdd(entity, id, component)
	local pool = self.pools[id]

	if pool:has(entity) then
		return
	end

	pool:assign(entity, component)
	pool.onAdd:dispatch(entity, component)

	return component
end

--[[

	Add the given components to the entity and return the entity.

]]
function Manifest:multiAdd(entity, ...)
	local num = select("#", ...)

	for i = 1, num, 2 do
		self:add(entity, select(i, ...), select(i + 1, ...))
	end

	return entity
end

--[[

	If the entity has the component, get and return the component.  Otherwise, add the
	component to the entity and return the component.

]]
function Manifest:getOrAdd(entity, id, component)
	local pool = self.pools[id]
	local idx = pool:has(entity)

	if idx then
		return pool.objects[idx]
	else
		pool:assign(entity, component)
		pool.onAdd:dispatch(entity, component)

		return component
	end
end

--[[

	Replace the component on the entity with the given component.

	Strict will throw upon an attempt to replacing a component that the entity does not
	have.

]]
function Manifest:replace(entity, id, component)
	local pool = self.pools[id]

	pool.onUpdate:dispatch(entity, component)
	pool.objects[pool:has(entity)] = component

	return component
end

--[[

	If the entity has the component, replace it with the given component and return the
	new component.  Otherwise, add the component to the entity and return the new
	component.

]]
function Manifest:addOrReplace(entity, id, component)
	local pool = self.pools[id]
	local idx = pool:has(entity)

	if idx then
		pool.onUpdate:dispatch(entity, component)
		pool.objects[idx] = component

		return component
	end

	pool:assign(entity, component)
	pool.onAdd:dispatch(entity, component)

	return component
end

--[[

	Remove the component from the entity.

	Strict will throw upon an attempt to remove a component which the entity does not
	have.

]]
function Manifest:remove(entity, id)
	local pool = self.pools[id]

	pool.onRemove:dispatch(entity, pool:get(entity))
	pool:destroy(entity)
end

--[[

	Remove all the specified components from the entity.

]]
function Manifest:multiRemove(entity, ...)
	for i = 1, select("#", ...) do
		local pool = self.pools[select(i, ...)]

		pool.onRemove:dispatch(entity, pool:get(entity))
		pool:destroy(entity)
	end
end

--[[

	If the entity has the component, remove it.  Otherwise, do nothing.

]]
function Manifest:tryRemove(entity, id)
	local pool = self.pools[id]

	if pool:has(entity) then
		pool.onRemove:dispatch(entity, pool:get(entity))
		pool:destroy(entity)

		return true
	end

	return false
end

--[[

	Return a signal that fires just after all components of the given types have been
	added to an entity.

]]
function Manifest:onAdded(...)
	local ids = { ... }
	local num = #ids

	if num == 1 then
		return self.pools[select(1, ...)].onAdd
	end

	local signal = Signal.new()
	local pools = table.create(num)
	local connections = table.create(num)
	local packed = table.create(num)

	for i, id in ipairs(ids) do
		pools[i] = self.pools[id]
	end

	for i, pool in ipairs(pools) do
		connections[i] = pool.onAdd:connect(function(entity)
			for k, checkedPool in ipairs(pools) do
				local idx = checkedPool:has(entity)

				if not idx then
					return
				end

				packed[k] = checkedPool.objects[idx]
			end

			signal:dispatch(entity, unpack(packed))
		end)
	end

	return signal, function()
		for _,  connection in ipairs(connections) do
			connection()
		end
	end
end

--[[

	Return a signal that fires just after a component of any of the given types have been
	removed from an entity that has all of them.

]]
function Manifest:onRemoved(...)
	local ids = { ... }
	local num = #ids

	if num == 1 then
		return self.pools[select(1, ...)].onRemove
	end

	local signal = Signal.new()
	local pools = table.create(num)
	local connections = table.create(num)
	local packed = table.create(num)

	for i, id in ipairs(ids) do
		pools[i] = self.pools[id]
	end

	for i, pool in ipairs(pools) do
		connections[i] = pool.onRemove:connect(function(entity)
			for k, checkedPool in ipairs(pools) do
				local idx = checkedPool:has(entity)

				if not idx then
					return
				end

				packed[k] = checkedPool.objects[idx]
			end

			signal:dispatch(entity, unpack(packed))
		end)
	end

	return signal, function()
		for _,  connection in ipairs(connections) do
			connection()
		end
	end
end

--[[

	Return a signal that fires just after a component of the given type has been updated.

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

--[[

	Return the bare structures used to keep track of entities and their components: a
	list of entities and a list of their corresponding components, both sorted the
	same way.

]]
function Manifest:raw(id)
	local pool = self.pools[id]
	return pool.dense, pool.objects
end

--[[

	Return the number of entities with the specified component.

]]
function Manifest:getSize(id)
	return self.pools[id].size
end

--[[

	Return the Pool object being used to manage the specified component.

]]
function Manifest:getPool(id)
	return self.pools[id]
end


--[[

	Return a constraint requiring that all the specified components be present on an
	entity.

]]
function Manifest:all(...)
	return Constraint.new(self, { ... })
end

--[[

	Return a constraint requiring that none of the specified components be present on an
	entity.

]]
function Manifest:except(...)
	return Constraint.new(self, nil, { ... })
end

--[[

	Return a constraint requiring that all the specified components both exist and have
	been updated on an entity.

]]
function Manifest:updated(...)
	return Constraint.new(self, nil, nil, { ... })
end

--[[

	Inject a context variable into the manifest.

]]
function Manifest:inject(context, value)
	self.contexts[context] = value
	return value
end

--[[

	Get a context variable from the manifest.

]]
function Manifest:context(context)
	local var = self.contexts[context]
	return var
end

return Manifest
