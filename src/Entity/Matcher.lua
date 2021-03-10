local Collection = require(script.Parent.Collection)
local ImmutableCollection = require(script.Parent.ImmutableCollection)

local Matcher = {}
Matcher.__index = Matcher

function Matcher.new(registry)
	return setmetatable({
		forbidden = {},
		optional = {},
		required = {},
		update = {},
		collection = {},

		_registry = registry,
	}, Matcher)
end

function Matcher:all(...)
	self.required = self._registry:getPools(...)

	return self
end

function Matcher:except(...)
	self.forbidden = self._registry:getPools(...)

	return self
end

function Matcher:updated(...)
	self.update = self._registry:getPools(...)

	return self
end

function Matcher:any(...)
	self.optional = self._registry:getPools(...)

	return self
end

function Matcher:collect()
	self.collection = Collection.new(self)

	return self.collection
end

function Matcher:immutable()
	return ImmutableCollection.new(self)
end

return Matcher
