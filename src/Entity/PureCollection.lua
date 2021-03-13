local SinglePureCollection = require(script.Parent.SinglePureCollection)
local util = require(script.Parent.Parent.util)

local PureCollection = {}
PureCollection.__index = PureCollection

local function ErrNeedsRequired()
	util.jumpAssert("Pure collections can only update required components")
end

function PureCollection.new(system)
	local registry = system.registry

	if #system.forbidden == 0 and #system.optional == 0 and #system.required == 1 then
		return SinglePureCollection.new(unpack(system.required))
	end

	return setmetatable({
		_required = registry:getPools(unpack(system.required)),
		_forbidden = registry:getPools(unpack(system.forbidden)),
		_optional = registry:getPools(unpack(system.optional)),
		_packed = table.create(#system.required + #system.optional),
		_numPacked = #system.required + #system.optional,
		_numRequired = #system.required,

		update = #system.required > 0 and PureCollection.update or ErrNeedsRequired
	}, PureCollection)
end

function PureCollection:update(callback)
	local packed = self._packed
	local numPacked = self._numPacked
	local shortest = self:_getShortestPool(self._required)

	for _, entity in ipairs(shortest.dense) do
		if self:_tryPack(entity) then
			self:_replace(entity, callback(entity, unpack(packed, 1, numPacked)))
		end
	end
end

function PureCollection:each(callback)
	local packed = self._packed
	local numPacked = self._numPacked
	local shortest = self:_getShortestPool(self._required)

	for _, entity in ipairs(shortest.dense) do
		if self:_tryPack(entity) then
			callback(entity, unpack(packed, 1, numPacked))
		end
	end
end

function PureCollection:_replace(entity, ...)
	for i, pool in ipairs(self._required) do
		local newComponent = select(i, ...)
		local oldComponent = pool:get(entity)

		if newComponent ~= oldComponent then
			-- !!! Beware: if a listener of this signal adds or removes any
			-- !!! elements from the pool selected by _getShortestPool, the
			-- !!! iteration will terminate!
			pool.updated:dispatch(entity, newComponent)
			pool:replace(entity, newComponent)
		end
	end
end

--[[
	Returns the required component pool with the least number of elements.
]]
function PureCollection:_getShortestPool(pools)
	local size = math.huge
	local selected

	for _, pool in ipairs(pools) do
		if pool.size < size then
			size = pool.size
			selected = pool
		end
	end

	return selected
end

function PureCollection:_tryPack(entity)
	local packed = self._packed

	for _, pool in ipairs(self._forbidden) do
		if pool:getIndex(entity) then
			return false
		end
	end

	for i, pool in ipairs(self._required) do
		local component = pool:get(entity)

		if not component then
			return false
		end

		packed[i] = component
	end

	local numRequired = self._numRequired

	for i, pool in ipairs(self._optional) do
		packed[numRequired + i] = pool:get(entity)
	end

	return true
end

return PureCollection
