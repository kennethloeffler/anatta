--[=[
	@class World

	A `World` contains a [`Registry`](/api/Registry) and provides means for both scoped and
	unscoped access to entities and components.

	You can get or create a `World` with [`Anatta.getWorld`](/api/Anatta#getWorld) and
	[`Anatta.createWorld`](/api/Anatta#createWorld).
]=]

--- @prop registry Registry
--- @within World
--- Provides direct, unscoped access to a `World`'s [`Registry`](/api/Registry).

--[=[
	@interface Query
	@within World
	.withAll {string}?
	.withUpdated {string}?
	.withAny {string}?
	.without {string}?

	A `Query` represents a component aggregation to retrieve from a
	[`Registry`](/api/Registry). A `Query` can be finalized by passing it to
	[`World:getReactor`](#getReactor) or [`World:getMapper`](#getMapper).

	Various [`Reactor`](/api/Reactor) and [`Mapper`](/api/Mapper) methods accept callbacks
	that are passed an entity and its components. Such callbacks receive the entity as the
	first argument, followed by the entity's components from `withAll`, then the
	components from `withUpdated`, and finally the components from `withAny`.

	### `Query.withAll`
	An entity must have all of the components specified in `withAll` to appear in the
	query.

	### `Query.withUpdated`
	An entity must have an updated copy of all the components specified in `withUpdated`
	to appear in the query.

	### `Query.withAny`
	An entity may have any or none of the components specified in `withAny` and still
	appear in the query.

	### `Query.without`
	An entity must not have any of the components specified in `without` to appear in the
	query.
]=]

local Mapper = require(script.Mapper)
local Reactor = require(script.Reactor)
local Registry = require(script.Registry)

local World = {}
World.__index = World

--[=[
	Creates a new `World` containing an empty [`Registry`](/api/Registry) and calls
	[`Registry:defineComponent`](/api/Registry#defineComponent) for each
	[`ComponentDefinition`](/api/Anatta#ComponentDefinition) in the given list.

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
		_reactorSystems = {},
	}, World)
end

--[=[
	Creates a new [`Mapper`](/api/Mapper) given a [`Query`](#Query).

	@error "Mappers cannot track updates to components"
	@error "Mappers need at least one component type specified in withAll"

	@param query Query
	@return Mapper
]=]
function World:getMapper(query)
	return Mapper.new(self.registry, query)
end

--[=[
	Creates a new [`Reactor`](/api/Reactor) given a [`Query`](#Query).

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

function World:addSystem(script)
	self._reactorSystems[script] = {}
end

function World:removeSystem(script)
	self._reactorSystems[script] = nil
end

return World
