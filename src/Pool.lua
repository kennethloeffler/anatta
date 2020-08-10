local Constants = require(script.Parent.Constants)
local Signal = require(script.Parent.core.Signal)

local ENTITYID_MASK = Constants.ENTITYID_MASK
local STRICT = Constants.STRICT

local ErrBadType = "bad component type: expected %s, got %s"

local Pool = {}
Pool.__index = Pool

local function componentTypeOk(underlyingType, component)
	local ty = typeof(component)
	local instanceTypeOk = false

	if ty == "Instance" then
		instanceTypeOk = component:IsA(underlyingType)
	end

	return (tostring(underlyingType) == ty) or instanceTypeOk,
	ErrBadType:format(tostring(underlyingType), typeof(component))
end

function Pool.new(name, dataType)
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
	return ("%s"):format(self.name)
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
	if STRICT then
		assert(componentTypeOk(self.underlyingType, component))
	end

	self.size += 1
	self.dense[self.size] = entity
	self.sparse[bit32.band(entity, ENTITYID_MASK)] = self.size

	if component then
		self.objects[self.size] = component

		return component
	end
end

function Pool:destroy(entity)
	self.size -= 1

	local sparseIdx = bit32.band(entity, ENTITYID_MASK)
	local denseIdx = self.sparse[sparseIdx]

	if denseIdx < self.size + 1 then
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
