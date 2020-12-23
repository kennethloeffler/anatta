local Constants = require(script.Parent.Parent.Core.Constants)
local SingleReducer = require(script.Parent.SingleReducer)

local ENTITYID_MASK = Constants.ENTITYID_MASK
local NONE = Constants.NONE

local Reducer = {}
Reducer.__index = Reducer

function Reducer.new(registry, components)
	local required = registry:getPools(unpack(components.required or NONE))
	local forbidden = registry:getPools(unpack(components.forbidden or NONE))

	assert(next(required), "Reducers must have at least one required component")

	if not next(forbidden) and #required == 1 then
		return SingleReducer.new(registry._pools[required[1]])
	end

	return setmetatable({
		_required = required,
		_forbidden = forbidden,
		_packed = table.create(#required),
	}, Reducer)
end

function Reducer:entities(callback)
	for _, entity in ipairs(self:_getShortestRequiredPool().dense) do
		if self:_try(entity) then
			callback(entity)
		end
	end
end

function Reducer:each(callback)
	for _, entity in ipairs(self:_getShortestRequiredPool().dense) do
		if self:_tryPack(entity) then
			self:_reduce(entity, callback(entity, unpack(self._packed)))
		end
	end
end

function Reducer:_reduce(entity, ...)
	for i, pool in ipairs(self._required) do
		pool.objects[pool.sparse[bit32.band(entity, ENTITYID_MASK)]] = select(i, ...)
	end
end

--[[
	Returns the required component pool with the least number of elements.
]]
function Reducer:_getShortestRequiredPool()
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

function Reducer:_try(entity)
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

function Reducer:_tryPack(entity)
	for _, pool in ipairs(self._forbidden) do
		if pool:contains(entity) then
			return false
		end
	end

	for i, pool in ipairs(self._required) do
		local denseIndex = pool:contains(entity)

		if not denseIndex then
			return false
		end

		self._packed[i] = pool.objects[denseIndex]
	end

	return true
end

return Reducer
