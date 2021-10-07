--[=[
	@class World

	A `World` contains a [`Registry`](Registry) and provides means for both scoped and
	unscoped access to entities and components.

	You can get or create a `World` with [`Anatta.getWorld`](Anatta#getWorld) and
	[`Anatta.createWorld`](Anatta#createWorld).
]=]

--- @prop registry Registry
--- @within World
--- Provides direct, unscoped access to a `World`'s [`Registry`](Registry).

local Mapper = require(script.Mapper)
local Reactor = require(script.Reactor)
local Registry = require(script.Registry)

local World = {}
World.__index = World

--[=[
	Creates a new `World` containing an empty [`Registry`](Registry) and calls
	[`Registry:defineComponent`](Registry#defineComponent) for each
	[`ComponentDefinition`](Anatta#ComponentDefinition) in the given list.

	@ignore
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
		_systemReactors = {},
	}, World)
end

--[=[
	Creates a new [`Mapper`](Mapper) given a [`Query`](#Query).

	@error "Mappers cannot track updates to components"
	@error "Mappers need at least one component type specified in withAll"

	@param query Query
	@return Mapper
]=]
function World:getMapper(query)
	return Mapper.new(self.registry, query)
end

--[=[
	Creates a new [`Reactor`](Reactor) given a [`Query`](#Query).

	@error "Reactors need at least one component type specified in withAll, withUpdated, or withAny"
	@error "Reactors can only track up to 32 updated component types"

	@param query Query
	@return Reactor
]=]
function World:getReactor(query, script)
	local reactor = Reactor.new(self.registry, query)

	if self._systemReactors[script] then
		table.insert(self._systemReactors[script], reactor)
	end

	return reactor
end

function World:_addSystem(script)
	self._systemReactors[script] = {}
end

function World:_removeSystem(script)
	self._systemReactors[script] = nil
end

function World:on(script, event, callback)
end

return World
