local Core = require(script.Parent.Core)

local Constants = Core.Constants
local Signal = Core.Signal

local ENTITYID_MASK = Constants.ENTITYID_MASK

local Pool = {}
Pool.__index = Pool

function Pool.new(name, typeDef)
	return setmetatable({
		name = name,
		typeDef = typeDef,

		onAdd = Signal.new(),
		onRemove = Signal.new(),
		onUpdate = Signal.new(),

		size = 0,
		sparse = {},
		dense = {},
		objects = {},
	}, Pool)
end

function Pool:has(entity)
	return self.sparse[bit32.band(entity, ENTITYID_MASK)]
end

function Pool:get(entity)
	return self.objects[self.sparse[bit32.band(entity, ENTITYID_MASK)]]
end

function Pool:assign(entity, component)
	self.size += 1

	local size = self.size
	local entityId = bit32.band(entity, ENTITYID_MASK)

	self.dense[size] = entity
	self.objects[size] = component
	self.sparse[entityId] = size

	return component
end

function Pool:destroy(entity)
	self.size -= 1

	local prevSize = self.size + 1
	local entityId = bit32.band(entity, ENTITYID_MASK)
	local denseIdx = self.sparse[entityId]

	self.sparse[entityId] = nil

	if denseIdx < prevSize then
		local swapped = self.dense[prevSize]

		self.dense[denseIdx] = swapped
		self.sparse[bit32.band(swapped, ENTITYID_MASK)] = denseIdx
		self.objects[denseIdx] = self.objects[prevSize]
	else
		self.dense[denseIdx] = nil
		self.objects[denseIdx] = nil
	end
end

return Pool
