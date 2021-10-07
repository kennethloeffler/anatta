local Constants = require(script.Parent.Constants)
local Signal = require(script.Parent.Signal)

local ENTITYID_MASK = Constants.EntityIdMask

local Pool = {}
Pool.__index = Pool

function Pool.new(componentDefinition)
	return setmetatable({
		componentDefinition = componentDefinition,
		typeCheck = componentDefinition.type.check,

		added = Signal.new(),
		removed = Signal.new(),
		updated = Signal.new(),

		size = 0,
		sparse = {},
		dense = {},
		components = {},
	}, Pool)
end

function Pool:getIndex(entity)
	return self.sparse[bit32.band(entity, ENTITYID_MASK)]
end

function Pool:get(entity)
	return self.components[self.sparse[bit32.band(entity, ENTITYID_MASK)]]
end

function Pool:replace(entity, component)
	self.components[self.sparse[bit32.band(entity, ENTITYID_MASK)]] = component
end

function Pool:insert(entity, component)
	self.size += 1

	local size = self.size
	local entityId = bit32.band(entity, ENTITYID_MASK)

	table.insert(self.dense, entity)
	table.insert(self.components, component)
	self.sparse[entityId] = size

	return component
end

function Pool:delete(entity)
	self.size -= 1

	local prevSize = self.size + 1
	local entityId = bit32.band(entity, ENTITYID_MASK)
	local denseIdx = self.sparse[entityId]

	if denseIdx < prevSize then
		local swapped = self.dense[prevSize]

		self.sparse[bit32.band(swapped, ENTITYID_MASK)] = denseIdx
		self.dense[denseIdx] = swapped
		self.components[denseIdx] = self.components[prevSize]
	else
		self.sparse[entityId] = nil
		table.remove(self.dense, prevSize)
		table.remove(self.components, prevSize)
	end
end

return Pool
