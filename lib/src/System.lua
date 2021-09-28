local Entity = require(script.Parent.Entity)
local util = require(script.Parent.util)

local System = {}
System.__index = System

local ErrPureCantHaveUpdated = "Pure collections cannot track updates to components"
local ErrPureNeedsComponents = "Pure collections need at least one required component type"
local ErrImpureNeedComponents =
	"Collections need least one required, updated, or optional component type"
local ErrTooManyUpdated = "Collections can only track up to 32 updated component types"

function System.new(registry)
	return setmetatable({
		forbidden = {},
		optional = {},
		required = {},
		update = {},
		registry = registry,

		_impureCollections = {},
		_connections = {},
	}, System)
end

function System:entitiesWithAll(...)
	self.required = { ... }
	return self
end

function System:entitiesWithUpdated(...)
	self.update = { ... }
	return self
end

function System:entitiesWithout(...)
	self.forbidden = { ... }
	return self
end

function System:entitiesWithAny(...)
	self.optional = { ... }
	return self
end

function System:collectEntities()
	util.jumpAssert(#self.update <= 32, ErrTooManyUpdated)
	util.jumpAssert(
		#self.required > 0 or #self.update > 0 or #self.optional > 0,
		ErrImpureNeedComponents
	)

	local collection = Entity.Collection.new(self)

	table.insert(self._impureCollections, collection)

	return collection
end

function System:freezeEntities()
	util.jumpAssert(#self.update == 0, ErrPureCantHaveUpdated)
	util.jumpAssert(#self.required > 0, ErrPureNeedsComponents)

	return Entity.PureCollection.new(self)
end

function System:unload()
	for _, collection in ipairs(self._impureCollections) do
		collection:detach()
	end

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
end

function System:on(event, callback)
	table.insert(self._connections, event:Connect(callback))
end

return System
