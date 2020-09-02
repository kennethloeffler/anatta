local Constants = require(script.Parent.Constants)
local Signal = require(script.Parent.core.Signal)

local ENTITYID_MASK = Constants.ENTITYID_MASK

local Pool = {}
Pool.__index = Pool

function Pool.new(name, tFunction)
	return setmetatable({
		name = name,
		tFunction = tFunction,

		onAdd = Signal.new(),
		onRemove = Signal.new(),
		onUpdate = Signal.new(),

		size = 0,
		sparse = {},
		dense = {},
		objects = {},
	}, Pool)
end

function Pool:__tostring()
	return self.name
end

function Pool:has(entity)
	local idx = self.sparse[bit32.band(entity, ENTITYID_MASK)]

	return (idx and idx <= self.size) and idx
end

function Pool:get(entity)
	local idx = self:has(entity)

	if idx then
		return self.objects[idx]
	end
end

function Pool:assign(entity, component)
	self.size += 1
	self.dense[self.size] = entity
	self.sparse[bit32.band(entity, ENTITYID_MASK)] = self.size

	if component then
		self.objects[self.size] = component

		return component
	end
end

function Pool:destroy(entity)
	local sparseIdx = bit32.band(entity, ENTITYID_MASK)
	local denseIdx = self.sparse[sparseIdx]
	local size = self.size

	self.size -= 1
	self.sparse[sparseIdx] = nil

	if denseIdx < size then
		local swapped = self.dense[size]

		self.dense[denseIdx] = swapped
		self.sparse[swapped] = denseIdx
		self.objects[denseIdx] = self.objects[size]
	else
		self.dense[denseIdx] = nil
		self.objects[denseIdx] = nil
	end

end

return Pool
