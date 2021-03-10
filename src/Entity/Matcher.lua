local Collection = require(script.Parent.Collection)
local ImmutableCollection = require(script.Parent.ImmutableCollection)
local util = require(script.Parent.Parent.util)

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
	util.jumpAssert(
		#self.required > 0 or #self.update > 0 or #self.optional > 0,
		"Collections must be given at least one required, updated, or optional component type"
	)

	util.jumpAssert(
		#self.update <= 32,
		"Collections may only track up to 32 updated component types"
	)

	self.collection = Collection.new(self)

	return self.collection
end

function Matcher:immutable()
	util.jumpAssert(
		#self.required > 0,
		"An immutable collection needs at least one required component"
	)

	return ImmutableCollection.new(self)
end

return Matcher
