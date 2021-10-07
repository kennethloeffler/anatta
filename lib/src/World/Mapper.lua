--[=[
	@class Mapper
]=]

local SingleMapper = require(script.Parent.SingleMapper)
local Types = require(script.Parent.Parent.Types)
local util = require(script.Parent.Parent.util)

local Mapper = {}
Mapper.__index = Mapper

local ErrCantHaveUpdated = "Mappers cannot track updates to components"
local ErrNeedComponents = "Mappers need at least one required component type"

local function ErrNeedsRequired()
	util.jumpAssert("Pure collections can only update required components")
end

function Mapper.new(registry, query)
	util.jumpAssert(Types.Query(query))

	local withAll = query.withAll or {}
	local withAny = query.withAny or {}
	local withUpdated = query.withUpdated or {}
	local without = query.without or {}

	util.jumpAssert(#withUpdated == 0, ErrCantHaveUpdated)
	util.jumpAssert(#withAll > 0, ErrNeedComponents)

	if #without == 0 and #withAny == 0 and #withAll == 1 then
		return SingleMapper.new(registry:getPool(query.withAll[1]))
	end

	return setmetatable({
		_required = registry:getPools(withAll),
		_forbidden = registry:getPools(without),
		_optional = registry:getPools(withAny),
		_packed = table.create(#withAll + #withAny),
		_numPacked = #withAll + #withAny,
		_numRequired = #withAll,

		update = #withAll > 0 and Mapper.update or ErrNeedsRequired,
	}, Mapper)
end

function Mapper:update(callback)
	local packed = self._packed
	local numPacked = self._numPacked
	local shortest = self:_getShortestPool(self._required)

	for _, entity in ipairs(shortest.dense) do
		if self:_tryPack(entity) then
			self:_replace(entity, callback(entity, unpack(packed, 1, numPacked)))
		end
	end
end

function Mapper:each(callback)
	local packed = self._packed
	local numPacked = self._numPacked
	local shortest = self:_getShortestPool(self._required)

	for _, entity in ipairs(shortest.dense) do
		if self:_tryPack(entity) then
			callback(entity, unpack(packed, 1, numPacked))
		end
	end
end

function Mapper:_replace(entity, ...)
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
function Mapper:_getShortestPool(pools)
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

function Mapper:_tryPack(entity)
	local packed = self._packed

	for _, pool in ipairs(self._forbidden) do
		if pool:getIndex(entity) then
			return false
		end
	end

	for i, pool in ipairs(self._required) do
		local index = pool:getIndex(entity)

		if not index then
			return false
		end

		packed[i] = pool.components[index]
	end

	local numRequired = self._numRequired

	for i, pool in ipairs(self._optional) do
		packed[numRequired + i] = pool:get(entity)
	end

	return true
end

return Mapper
