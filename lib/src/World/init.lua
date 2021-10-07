--[=[
	@class World

	A `World` contains a `Registry` and provides methods to get scoped access via
	[`Reactor`](Reactor)s and [`Mapper`](Mapper) and exposes a property to access the
	`Registry` directly.
]=]

--- @prop registry Registry
--- @within World
--- The `World`'s [`Registry`](Registry).

local Mapper = require(script.Mapper)
local Reactor = require(script.Reactor)
local Registry = require(script.Registry)

local World = {}
World.__index = World

--[=[
	Creates a new `World` containing an empty [`Registry`](Registry) and calls
	[`Registry:defineComponent`](Registry#defineComponent) for each
	[`ComponentDefinition`](Anatta#ComponentDefinition) in the given list.

	@param componentDefinitions {ComponentDefinition}
	@return World
]=]
function World.new(componentDefinitions)
	local registry = Registry.new()

	for _, componentDefinition in ipairs(componentDefinitions) do
		registry:defineComponent(componentDefinition)
	end

	return setmetatable({
		registry = registry,
	}, World)
end

--[=[
	Creates a new [`Mapper`](Mapper) given a [`Query`](Anatta#Query).
	@param query Query
	@return Mapper
]=]
function World:getMapper(query)
	return Mapper.new(self.registry, query)
end

--[=[
	Creates a new [`Reactor`](Reactor) given a [`Query`](Anatta#Query).
	@param query Query
	@return Reactor
]=]
function World:getReactor(query)
	return Reactor.new(self.registry, query)
end

return World
