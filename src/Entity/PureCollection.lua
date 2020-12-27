local Constants = require(script.Parent.Parent.Core.Constants)
local SinglePureCollection = require(script.Parent.SinglePureCollection)

local ENTITYID_MASK = Constants.ENTITYID_MASK
local NONE = Constants.NONE

local PureCollection = {}
PureCollection.__index = PureCollection

function PureCollection.new(registry, components)
	local required = registry:getPools(unpack(components.required or NONE))
	local forbidden = registry:getPools(unpack(components.forbidden or NONE))

	assert(next(required), "PureCollections must have at least one required component")

	if not next(forbidden) and #required == 1 then
		return SinglePureCollection.new(registry._pools[required[1]])
	end

	return setmetatable({
		_required = required,
		_forbidden = forbidden,
		_packed = table.create(#required),
	}, PureCollection)
end

function PureCollection:entities(callback)
	for _, entity in ipairs(self:_getShortestRequiredPool().dense) do
		if self:_try(entity) then
			callback(entity)
		end
	end
end

function PureCollection:each(callback)
	for _, entity in ipairs(self:_getShortestRequiredPool().dense) do
		if self:_tryPack(entity) then
			self:_reduce(entity, callback(entity, unpack(self._packed)))
		end
	end
end

function PureCollection:_reduce(entity, ...)
	for i, pool in ipairs(self._required) do
		pool.objects[pool.sparse[bit32.band(entity, ENTITYID_MASK)]] = select(i, ...)
	end
end

--[[
	Returns the required component pool with the least number of elements.
]]
function PureCollection:_getShortestRequiredPool()
	local size = math.huge
	local selected

	for _, pool in ipairs(self._required) do
		if pool.size < size then
			size = pool.size
			selected = pool
		end
	end

	return selected
end

function PureCollection:_try(entity)
	for _, pool in ipairs(self._forbidden) do
		if pool:contains(entity) then
			return false
		end
	end

	for _, pool in ipairs(self._required) do
		if not pool:contains(entity) then
			return false
		end
	end

	return true
end

function PureCollection:_tryPack(entity)
	for _, pool in ipairs(self._forbidden) do
		if pool:getIndex(entity) then
			return false
		end
	end

	for i, pool in ipairs(self._required) do
		local denseIndex = pool:getIndex(entity)

		if not denseIndex then
			return false
		end

		self._packed[i] = pool.objects[denseIndex]
	end

	return true
end

return PureCollection
