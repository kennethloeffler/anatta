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
	.withAll {ComponentDefinition}?
	.withUpdated {ComponentDefinition}?
	.withAny {ComponentDefinition}?
	.without {ComponentDefinition}?

	A `Query` represents a set of entities to retrieve from a
	[`Registry`](/api/Registry). A `Query` can be finalized by passing it to
	[`World:getReactor`](#getReactor) or [`World:getMapper`](#getMapper).

	The fields of a `Query` determine which entities are yielded. Each field is an
	optional list of component names that corresponds to one of the following rules:

	### `Query.withAll`
	An entity must have all of these components.

	### `Query.withUpdated`
	An entity must have an updated copy of all of these components.

	:::warning
	A [`Mapper`](/api/Mapper) cannot track updates to
	components. [`World:getMapper`](#getMapper) throws an error when this field is
	included.
	:::

	### `Query.withAny`
	An entity may have any or none of these components.

	### `Query.without`
	An entity must not have any of these components.

	Methods like [`Reactor:withAttachments`](/api/Reactor#withAttachments) and
	[`Mapper:each`](/api/Mapper#each) take callbacks that are passed an entity and its
	components. Such callbacks receive an entity as their first argument, followed in
	order by the entity's components from `withAll`, then the components from
	`withUpdated`, and finally the components from `withAny`.
]=]
local Mapper = require(script.Mapper)
local Reactor = require(script.Reactor)
local Registry = require(script.Registry)

local util = require(script.Parent.util)

local ErrMappersCantHaveUpdated = "mappers cannot track updates; use a reactor instead"
local ErrMappersNeedComponents = "mappers need at least one component provided in withAll"
local ErrReactorsNeedComponents =
	"reactors need at least one component type provided in withAll, withUpdated, or withAny"
local ErrTooManyUpdated = "reactors can only track up to 32 updated component types"
local ErrInvalidComponentDefinition = 'The component type "%s" is not defined for this world'

local World = {}
World.__index = World

--[=[
	@prop components {[string]: ComponentDefinition}
	@within World

	A dictionary mapping component names to component definitions. Intended to be used for importing
	component definitions as follows:
	```lua
	-- Assuming we've already defined the World elsewhere with a component called "Money"
	local world = Anatta:getWorld("MyCoolWorld")
	local registry = world.registry

	local Money = world.components.Money

	registry:addComponent(registry:createEntity(), Money, 5000)
	```
]=]

--[=[
	Creates a new `World` containing an empty [`Registry`](/api/Registry) and calls
	[`Registry:defineComponent`](/api/Registry#defineComponent) for each
	[`ComponentDefinition`](/api/Anatta#ComponentDefinition) in the given list.

	@ignore
	@param definitions {ComponentDefinition}
	@return World
]=]
function World.new(definitions)
	local registry = Registry.new()

	local components = {}

	for _, definition in ipairs(definitions) do
		registry:defineComponent(definition)
		components[definition.name] = definition
	end

	return setmetatable({
		components = setmetatable(components, {
			__index = function(self, componentName)
				util.jumpAssert(
					rawget(self, componentName) ~= nil,
					ErrInvalidComponentDefinition,
					componentName
				)
			end,
		}),
		registry = registry,
		_reactorSystems = {},
	}, World)
end

--[=[
	Creates a new [`Mapper`](/api/Mapper) given a [`Query`](#Query).

	@error "mappers cannot track updates to components; use a Reactor instead" -- Reactors can track updates. Mappers can't.
	@error "mappers need at least one component type provided in withAll" -- Mappers need components in withAll to query.
	@error 'the component type "%s" is not defined for this world" -- No component matches that definition.

	@param query Query
	@return Mapper
]=]
function World:getMapper(query)
	local withAll = query.withAll or {}
	local withUpdated = query.withUpdated or {}

	util.jumpAssert(#withUpdated == 0, ErrMappersCantHaveUpdated)
	util.jumpAssert(#withAll > 0, ErrMappersNeedComponents)

	for _, components in pairs(query) do
		for _, definintion in ipairs(components) do
			util.jumpAssert(
				self.registry:isComponentDefined(definintion),
				ErrInvalidComponentDefinition,
				definintion
			)
		end
	end

	return Mapper.new(self.registry, query)
end

--[=[
	Creates a new [`Reactor`](/api/Reactor) given a [`Query`](#Query).

	@error "reactors need at least one component type provided in withAll, withUpdated, or withAny" -- Reactors need components to query.
	@error "reactors can only track up to 32 updated component types" -- More than 32 components were provided in withUpdated.
	@error 'the component type "%s" is not defined for this world" -- No component matches that definition.

	@param query Query
	@return Reactor
]=]
function World:getReactor(query, script)
	local withAll = query.withAll or {}
	local withUpdated = query.withUpdated or {}
	local withAny = query.withAny or {}

	util.jumpAssert(#withUpdated <= 32, ErrTooManyUpdated)
	util.jumpAssert(#withAll > 0 or #withUpdated > 0 or #withAny > 0, ErrReactorsNeedComponents)

	for _, components in pairs(query) do
		for _, definition in ipairs(components) do
			util.jumpAssert(
				self.registry:isComponentDefined(definition),
				ErrInvalidComponentDefinition,
				definition
			)
		end
	end

	local reactor = Reactor.new(self.registry, query)

	if self._reactorSystems[script] then
		table.insert(self._reactorSystems[script], reactor)
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
