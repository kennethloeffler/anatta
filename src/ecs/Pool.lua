local Constants = require(script.Parent.Constants)
local Signal = require(script.Parent.Parent.core.Signal)

local ENTITYID_MASK = Constants.ENTITYID_MASK

local Pool = {}
Pool.__index = Pool

function Pool.new(name, dataType, capacity)
	return setmetatable({
		name = name,
		underlyingType = dataType,

		onAssign = Signal.new(),
		onRemove = Signal.new(),
		onUpdate = Signal.new(),

		size = 0,
		sparse = {},
		dense = {},
		objects = {},
	}, Pool)
end

function Pool:__tostring()
	return ("%s: %s"):format(self.name, self.underlyingType)
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

function Pool:assign(entity, object)
	local size = self.size + 1

	self.size = size
	self.dense[size] = entity
	self.sparse[bit32.band(entity, ENTITYID_MASK)] = size

	if self.underlyingType then
		self.objects[size] = object

		return object
	end
end

function Pool:destroy(entity)
	local sparseIdx = bit32.band(entity, ENTITYID_MASK)
	local denseIdx = self.sparse[sparseIdx]
	local size = self.size

	self.size = size - 1

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

function Pool:clear()
	-- does this pool contain tag components?
	if self.underlyingType then
		for i, entity in ipairs(self.sparse) do
			self.dense[i] = nil
			self.sparse[entity] = nil
			self.objects[i] = nil
		end
	else
		for i, entity in ipairs(self.dense) do
			self.dense[i] = nil
			self.sparse[entity] = nil
		end
	end
end

return Pool
