local Constants = require(script.Parent.Parent.Constants)

local ENTITYID_WIDTH = Constants.ENTITYID_WIDTH
local ENTITYID_MASK = Constants.ENTITYID_MASK

local FullLoader = {}
FullLoader.__index = FullLoader

local readEntities
local readComponents

function FullLoader.new(destination, create)
	return setmetatable({
		destination = destination,
		create = create,
		currentIndex = 0
	}, FullLoader)
end

function FullLoader:entities(container)
	local read = container.readEntities or readEntities

	self.currentIndex = read(container, self.currentIndex, self.create, false)

	return self
end

function FullLoader:destroyed(container)
	local read = container.readEntities or readEntities

	self.currentIndex = read(container, self.currentIndex, self.create, true)

	return self
end

function FullLoader:components(container, ...)
	local readComp = container.readComponents

	local read
	local create = self.create
	local manifest = self.destination
	local idx = self.currentIndex

	for _, componentId in ipairs({ ... }) do
		read = (readComp and readComp[componentId])
			and readComp[componentId]
			or readComponents

		idx = read(container, idx, create, manifest, componentId)
	end

	self.currentIndex = idx

	return self
end

function FullLoader:stubs()
	local dest = self.destination
	local entities = dest.entities
	local entityId

	dest:forEach(function(entity)
		if dest:stub(entity) then
			entityId = bit32.band(entity, ENTITYID_MASK)
			entities[entityId] = bit32.bor(
				dest.head,
				bit32.lshift(bit32.rshift(entity, ENTITYID_WIDTH), ENTITYID_WIDTH))
			dest.head = entityId
		end
	end)
end

readEntities = function(container, idx, create, destroy)
	idx = idx + 1

	for _, entity in ipairs(container[idx]) do
		create(entity, destroy)
	end

	return idx
end

readComponents = function(container, idx, create, manifest, componentId)
	idx = idx + 2

	local entities = container[idx - 1]
	local components = container[idx]

	for i, entity in ipairs(entities) do
		create(entity, false)
		manifest:assign(entity, componentId, components[i])
	end

	return idx
end


return FullLoader
