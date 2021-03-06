local Matcher = {}
Matcher.__index = Matcher

function Matcher.new(registry)
	return setmetatable({
		_numForbidden = 0,
		_numOptional = 0,
		_numRequired = 0,
		_numUpdated = 0,

		_forbidden = {},
		_optional = {},
		_required = {},
		_updated = {},

		_registry = registry,
	}, Matcher)
end

function Matcher:all(...)
	self._numRequired = select("#", ...)
	self._required = self._registry:getPools(...)

	return self
end

function Matcher:except(...)
	self._numForbidden = select("#", ...)
	self._forbidden = self._registry:getPools(...)

	return self
end

function Matcher:updated(...)
	self._numUpdated = select("#", ...)
	self._updated = self._registry:getPools(...)

	return self
end

function Matcher:any(...)
	self._numOptional = select("#", ...)
	self._optional = self._registry:getPools(...)

	return self
end

return Matcher
