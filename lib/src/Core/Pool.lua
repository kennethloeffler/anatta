local Constants = require(script.Parent.Constants)
local Signal = require(script.Parent.Signal)

local ENTITYID_MASK = Constants.ENTITYID_MASK

local Pool = {}
Pool.__index = Pool

function Pool.new(name, typeDefinition)
	return setmetatable({
		name = name,
		typeCheck = typeDefinition.check,
		typeDefinition = typeDefinition,

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

	self.dense[size] = entity
	self.components[size] = component
	self.sparse[entityId] = size

	return component
end

function Pool:delete(entity)
	self.size -= 1

	local prevSize = self.size + 1
	local entityId = bit32.band(entity, ENTITYID_MASK)
	local denseIdx = self.sparse[entityId]

	self.sparse[entityId] = nil

	if denseIdx < prevSize then
		local swapped = self.dense[prevSize]

		self.dense[denseIdx] = swapped
		self.sparse[bit32.band(swapped, ENTITYID_MASK)] = denseIdx
		self.components[denseIdx] = self.components[prevSize]
	else
		self.dense[denseIdx] = nil
		self.components[denseIdx] = nil
	end
end

return Pool
