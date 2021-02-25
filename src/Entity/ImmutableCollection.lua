local SingleImmutableCollection = require(script.Parent.SingleImmutableCollection)
local util = require(script.Parent.Parent.util)

local None = util.createSymbol("None")

local ImmutableCollection = {}
ImmutableCollection.__index = ImmutableCollection

function ImmutableCollection.new(registry, components)
	local required = registry:getPools(unpack(components.all or None))
	local forbidden = registry:getPools(unpack(components.never or None))
	local optional = registry:getPools(unpack(components.any or None))

	util.assertAtCallSite(
		next(required),
		"A pure collection needs at least one required component"
	)

	if not next(forbidden) and not next(optional) and #required == 1 then
		return SingleImmutableCollection.new(unpack(required))
	end

	return setmetatable({
		none = None,

		_required = required,
		_forbidden = forbidden,
		_optional = optional,
		_packed = table.create(#required + #optional),
		_numRequired = #required,
	}, ImmutableCollection)
end

function ImmutableCollection:each(callback)
	for _, entity in ipairs(self:_getShortestRequiredPool().dense) do
		if self:_tryPack(entity) then
			self:_apply(entity, callback(entity, unpack(self._packed)))
		end
	end
end

function ImmutableCollection:_apply(entity, ...)
	for i, pool in ipairs(self._required) do
		local component = select(i, ...)

		if pool:replace(entity, component) then
			-- !!! Beware: if a listener to this signal adds or removes any elements
			-- !!! from the pool selected by _selectShortestPool, the iteration will
			-- !!! terminate!
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
		local denseIndex = pool:getIndex(entity)

		if not denseIndex then
			return false
		end

		packed[i] = pool.objects[denseIndex]
	end

	local numRequired = self._numRequired

	for i, pool in ipairs(self._optional) do
		local denseIndex = pool:getIndex(entity)

		if denseIndex then
			packed[numRequired + i] = pool.objects[denseIndex] or None
		else
			packed[numRequired + i] = None
		end
	end

	return true
end

return ImmutableCollection
