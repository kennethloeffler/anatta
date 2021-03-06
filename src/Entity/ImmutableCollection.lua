local SingleImmutableCollection = require(script.Parent.SingleImmutableCollection)
local util = require(script.Parent.Parent.util)

local ImmutableCollection = {}
ImmutableCollection.__index = ImmutableCollection

function ImmutableCollection.new(matcher)
	local numRequired = matcher._numRequired
	local numForbidden = matcher._numForbidden
	local numOptional = matcher._numOptional

	util.assertAtCallSite(
		numRequired > 0,
		"An immutable collection needs at least one required component"
	)

	if numForbidden == 0 and numOptional == 0 and numRequired == 1 then
		return SingleImmutableCollection.new(unpack(matcher._required))
	end

	return setmetatable({
		_required = matcher._required,
		_forbidden = matcher._forbidden,
		_optional = matcher._optional,
		_packed = table.create(numRequired + numOptional),
		_numPacked = numRequired + numOptional,
		_numRequired = numRequired,
	}, ImmutableCollection)
end

function ImmutableCollection:each(callback)
	local packed = self._packed
	local numPacked = self._numPacked

	for _, entity in ipairs(self:_getShortestRequiredPool().dense) do
		if self:_tryPack(entity) then
			self:_apply(entity, callback(entity, unpack(packed, 1, numPacked)))
		end
	end
end

function ImmutableCollection:_apply(entity, ...)
	for i, pool in ipairs(self._required) do
		local component = select(i, ...)

		if pool:replace(entity, component) then
			-- !!! Beware: if a listener of this signal adds or removes any
			-- !!! elements from the pool selected by _selectShortestPool, the
			-- !!! iteration will terminate!
			pool.onUpdated:dispatch(entity, component)
		end
	end
end

--[[
	Returns the required component pool with the least number of elements.
]]
function ImmutableCollection:_getShortestRequiredPool()
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

function ImmutableCollection:_tryPack(entity)
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

return ImmutableCollection
