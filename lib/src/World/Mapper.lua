--[=[
	@class Mapper

	Provides scoped access to a [`Registry`](/api/Registry) according to a
	[`Query`](/api/World#Query).

	A `Mapper` is stateless. In contrast to a [`Reactor`](/api/Reactor), a `Mapper` cannot
	track updates to components with [`Query.withUpdated`](/api/World#Query).

	You can create a `Mapper` using [`World:getMapper`](/api/World#getMapper).
]=]

local SingleMapper = require(script.Parent.SingleMapper)
local Types = require(script.Parent.Parent.Types)

local util = require(script.Parent.Parent.util)

local Mapper = {}
Mapper.__index = Mapper

function Mapper.new(registry, query)
	util.jumpAssert(Types.Query(query))

	local withAll = query.withAll or {}
	local withAny = query.withAny or {}
	local without = query.without or {}

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
	}, Mapper)
end

--[=[
	@param callback (entity: number, ...any) -> ...any

	Maps over entities that satisfy the [`Query`](/api/World#Query). Calls the callback
	for each entity, passing each entity followed by the components named in the
	[`Query`](/api/World#Query), and replaces the components in
	[`Query.withAll`](/api/World#Query) with the callback's return value. The replacement
	is equivalent a [`Registry:replaceComponent`](/api/Registry#replaceComponent) call.

	:::warning
	Adding or removing any of the components named in [`Query.withAll`](/api/World#Query)
	is forbidden inside of the callback. There are currently no protections against this,
	so be careful!
]=]
function Mapper:map(callback)
	local packed = self._packed
	local numPacked = self._numPacked
	local shortest = self:_getShortestPool(self._required)

	for _, entity in ipairs(shortest.dense) do
		if self:_tryPack(entity) then
			self:_replace(entity, callback(entity, unpack(packed, 1, numPacked)))
		end
	end
end

--[=[
	@param callback (entity: number, ...any) -> ()

	Iterates over all entities that satisfy the `Query`. Calls the callback for each
	entity, passing each entity followed by the components named in the `Query`.

	:::warning
	Adding or removing any of the components named in [`Query.withAll`](/api/World#Query)
	is forbidden inside of the callback. There are currently no protections against this,
	so be careful!
]=]
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

function Mapper:find(callback)
	local packed = self._packed
	local numPacked = self._numPacked
	local shortest = self:_getShortestPool(self._required)

	for _, entity in ipairs(shortest.dense) do
		if self:_tryPack(entity) then
			local result = callback(entity, unpack(packed, 1, numPacked))

			if result ~= nil then
				return result
			end
		end
	end

	return nil
end

function Mapper:filter(callback)
	local results = {}
	local packed = self._packed
	local numPacked = self._numPacked
	local shortest = self:_getShortestPool(self._required)

	for _, entity in ipairs(shortest.dense) do
		if self:_tryPack(entity) then
			local result = callback(entity, unpack(packed, 1, numPacked))

			if result ~= nil then
				table.insert(results, result)
			end
		end
	end

	return results
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
