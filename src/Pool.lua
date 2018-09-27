local Constants = require(script.Parent.Constants)
local Signal = require(script.Parent.core.Signal)

local ENTITYID_MASK = Constants.ENTITYID_MASK
local STRICT = Constants.STRICT

local ErrBadType = "bad component type: expected %s, got %s"

local Pool = {}
Pool.__index = Pool

local function componentTypeOk(underlyingType, component)
	local ty = typeof(component)
	local ok = true

	if ty == "Instance" then
		ok = component:IsA(underlyingType)
	end

	return (tostring(underlyingType) == ty) or ok,
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
	local size = self.size + 1

	if STRICT then
		assert(componentTypeOk(self.underlyingType, component))
	end

	self.size = size
	self.dense[size] = entity
	self.sparse[bit32.band(entity, ENTITYID_MASK)] = size

	if self.underlyingType then
		self.objects[size] = component

		return component
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
