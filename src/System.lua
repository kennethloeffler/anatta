local Entity = require(script.Parent.Entity)
local util = require(script.Parent.util)

local System = {}
System.__index = System

local ErrAlreadyHasCollection = "Systems can only create one collection"
local ErrPureNeedComponents = "Pure collections need at least one required component type"
local ErrImpureNeedComponents = "Collections need least one required, updated, or optional component type"
local ErrTooManyUpdated = "Collections can only track up to 32 updated component types"

function System.new()
	return setmetatable({
		forbidden = {},
		optional = {},
		required = {},
		update = {},

		_hasCollection = false,
		_connections = {},
	}, System)
end

function System:unload()
	if self._impureCollection then
		self._impureCollection:detach()
	end

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
end

function System:on(event, callback)
	table.insert(self._connections, event:Connect(callback))
end

function System:all(...)
	self.required = { ... }
	return self
end

function System:except(...)
	self.forbidden = { ... }
	return self
end

function System:updated(...)
	self.update = { ... }
	return self
end

function System:any(...)
	self.optional = { ... }
	return self
end

function System:collect()
	util.jumpAssert(not self._hasCollection, ErrAlreadyHasCollection)
	util.jumpAssert(#self.update <= 32, ErrTooManyUpdated)
	util.jumpAssert(#self.required > 0 or #self.update > 0 or #self.optional > 0, ErrImpureNeedComponents)

	self._hasCollection = true
	self._impureCollection = Entity.Collection.new(self)

	return self._impureCollection
end

function System:pure()
	util.jumpAssert(not self._hasCollection, ErrAlreadyHasCollection)
	util.jumpAssert(#self.required > 0, ErrPureNeedComponents)

	self._hasCollection = true
	return Entity.PureCollection.new(self)
end

return System
