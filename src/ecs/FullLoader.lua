local Constants = require(script.Parent.Constants)

local ENTITYID_MASK = Constants.ENTITYID_MASK
local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH

local FullLoader = {}
FullLoader.__index = FullLoader

local move = table.move
	and table.move
	or function(t1, f, e, t, t2)
		for i = f, e do
			t2[t] = t1[i]
			t = t + 1
		end
		return t2
	   end


local defaultReadNext
local identity

function FullLoader.new(destination)
	assert(destination.size == 0, "manifest must be empty")

	return setmetatable({
		destination = destination,
	}, FullLoader)
end

function FullLoader:entities(source)
	local dest = self.destination
	local destEntities = dest.entities
	local read = source.readNext or defaultReadNext
	local readEntity = source.readEntity
	local entities = read(source)

	if not readEntity then
		move(entities, 1, #entities, 1, destEntities)

		for i, entity in ipairs(entities) do
			if bit32.band(entity, ENTITYID_MASK) ~= i then
				destEntities[i] = bit32.bor(
					dest.head,
					bit32.lshift(bit32.rshift(entity, ENTITYID_WIDTH), ENTITYID_WIDTH))
				dest.head = i
			end
		end
	else
		for i, entity in ipairs(entities) do
			entity = readEntity(source, entity)

			if bit32.band(entity, ENTITYID_MASK) ~= i then
				destEntities[i] = bit32.bor(
					dest.head,
					bit32.lshift(bit32.rshift(entity, ENTITYID_WIDTH), ENTITYID_WIDTH))
				dest.head = i
			else
				destEntities[i] = entity
			end
		end
	end

	dest.size = #entities

	return self
end

function FullLoader:components(source, ...)
	local readComps = source.readComponents
	local dest = self.destination
	local readNext = source.readNext or defaultReadNext
	local readEntity = source.readEntity or identity
	local read
	local entities

	for _, componentId in ipairs({ ... }) do
		read = (readComps and readComps[componentId])
			and readComps[componentId]
			or identity

		entities = readNext(source)

		if not dest:_getPool(componentId) then
			for _, entity in ipairs(entities) do
				entity = readEntity(entity)
				dest:assign(dest:valid(entity) and entity or dest:create(entity), componentId)
			end
		else
			local components = readNext(source)

			for i, entity in ipairs(entities) do
				entity = readEntity(entity)
				dest:assign(dest:valid(entity) and entity or dest:create(entity), componentId, read(components[i]))
			end
		end
	end

	return self
end

function FullLoader:stubs()
	local dest = self.destination

	dest:forEach(function(entity)
		if dest:stub(entity) then
			dest:destroy(entity)
		end
	end)

	return self
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

identity = function(x)
	return x
end

return FullLoader
