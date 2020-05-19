local Constants = require(script.Parent.Constants)

local ENTITYID_MASK = Constants.ENTITYID_MASK
local STRICT = Constants.STRICT

local PiecewiseLoader = {}
PiecewiseLoader.__index = PiecewiseLoader

local ContainerBadType = "bad argument #2 (expected table or number, got %s)"
local EntityBadType = "expected table to contain number values"

local defaultReadNext
local update
local restore
local restoreDestroyed
local identity

function PiecewiseLoader.new(destination)
	return setmetatable({
		destination = destination,
		dirty = {},
		mirrored = {}
	}, PiecewiseLoader)
end

function PiecewiseLoader:entity(entity, source)
	if source and source.readEntity then
		entity = source.readEntity(source, entity)
	end

	-- impossible to tell if an arbitrary remote entity is destroyed - if it hasn't
	-- been mirrored yet, we must destroy it to deref it automatically if it is not
	-- in use after the next clean cycle
	 restoreDestroyed(entity, self.mirrored, self.dirty, self.destination)
end

function PiecewiseLoader:component(entity, componentId, component, members, source)
	local destination = self.destination
	local mirrored = self.mirrored

	if source then
		local readEntity = source.readEntity
		local readComponent = source.readComponents and source.readComponents[componentId]

		if readEntity then
			entity = readEntity(source, entity)
		end

		if readComponent then
			component = readComponent(source, component)
		end
	end

	restore(entity, mirrored, self.dirty, destination)

	if members then
		for _, member in ipairs(members) do
			update(component, member, mirrored)
		end
	end

	destination:assignOrReplace(mirrored[entity], componentId, component)
end

function PiecewiseLoader:entities(source)
	local readNext = source.readNext or defaultReadNext
	local mirrored = self.mirrored
	local dirty = self.dirty
	local destination = self.destination

	for i, entity in ipairs(readNext(source)) do
		if bit32.band(entity, ENTITYID_MASK) == i then
			-- only the entity ids in sequence are guaranteed to be non-destroyed
			restore(entity, mirrored, dirty, destination)
		else
			-- ids out of sequence might be destroyed
			restoreDestroyed(entity, mirrored, dirty, destination)
		end
	end

	return self
end

function PiecewiseLoader:components(source, componentIds, members)
	local readComponents = source.readComponents
	local readEntity = source.readEntity or identity
	local readNext = source.readNext or defaultReadNext
	local destination = self.destination
	local mirrored = self.mirrored
	local dirty = self.dirty
	local componentMembers
	local readComponent
	local entities
	local components
	local component

	for _, mirrorEntity in pairs(mirrored) do
		if destination:valid(mirrorEntity) then
			for _, componentId in ipairs(componentIds) do
				destination:removeIfHas(mirrorEntity, componentId)
			end
		end
	end

	for _, componentId in ipairs(componentIds) do
		readComponent = (readComponents and readComponents[componentId])
			and readComponents[componentId]
			or identity

		entities = readNext(source)

		if not destination:_getPool(componentId).type then
			for _, entity in ipairs(entities) do
				entity = readEntity(source, entity)
				restore(entity, mirrored, dirty, destination)
				destination:assignOrReplace(mirrored[entity], componentId)
			end
		else
			components = readNext(source)
			componentMembers = members and members[componentId]

			if componentMembers then
				for i, entity in ipairs(entities) do
					entity = readEntity(source, entity)
					component = readComponent(source, components[i])

					restore(entity, mirrored, dirty, destination)

					for _, member in ipairs(componentMembers) do
						update(component, member, mirrored)
					end

					destination:assignOrReplace(mirrored[entity], componentId, component)
				end
			else
				for i, entity in ipairs(entities) do
					entity = readEntity(source, entity)
					restore(entity, mirrored, dirty, destination)
					destination:assignOrReplace(mirrored[entity], componentId, readComponent(components[i]))
				end
			end
		end
	end

	return self
end

function PiecewiseLoader:stubs()
	local destination = self.destination

	destination:forEach(function(entity)
		if destination:stub(entity) then
			destination:destroy(entity)
		end
	end)

	return self
end

function PiecewiseLoader:clean()
	local mirrored = self.mirrored
	local dirty = self.dirty
	local destination = self.destination

	for entity, mirrorEntity in pairs(mirrored) do
		if dirty[entity] then
			dirty[entity] = false
		else
			if destination:valid(mirrorEntity) then
				destination:destroy(mirrorEntity)
			end

			mirrored[entity] = nil
			dirty[entity] = nil
		end
	end
end

identity = function(_, x)
	return x
end

defaultReadNext = function(source)
	local idx = (source._idx or 0) + 1

	if idx == #source then
		source._idx = nil
	else
		source._idx = idx
	end

	return source[idx]
end

restore = function(entity, mirrored, dirty, destination)
	local mirrorEntity = mirrored[entity]

	if not mirrorEntity then
		mirrored[entity] = destination:create()
		dirty[entity] = true
	else
		mirrored[entity] = destination:valid(mirrorEntity) and mirrorEntity or destination:create()
		dirty[entity] = true
	end
end

restoreDestroyed = function(entity, mirrored, dirty, destination)
	local mirrorEntity = mirrored[entity]

	if not mirrorEntity then
		mirrorEntity = destination:create()
		destination:destroy(mirrorEntity)

		mirrored[entity] = mirrorEntity
		dirty[entity] = true
	end
end

update = function(component, member, mirrored)
	local memberVal = component[member]
	local ty = typeof(memberVal)

	if STRICT then
		assert(ty == "number" or ty == "table", ContainerBadType:format(ty))

		if ty == "table" then
			for _, v in pairs(memberVal) do
				assert(type(v) == "number", EntityBadType)
			end
		end
	end

	if ty == "table" then
		local iter = #memberVal ~= 0 and ipairs or pairs

		for i, entity in iter(memberVal) do
			memberVal[i] = mirrored[entity]
		end
	elseif ty == "number" then
		component[member] = mirrored[memberVal]
	end
end

return PiecewiseLoader
