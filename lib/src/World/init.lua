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
	optional list of `ComponentsDefinition`s that corresponds to a rule:

	| Field       | Rule                                                            |
	|-------------|-----------------------------------------------------------------|
	| withAll     | An entity must have all of these components.                    |
	| withUpdated | An entity must have an updated copy of all of these components. |
	| withAny     | An entity may have any or none of these components.             |
	| without     | An entity must not have any of these components.                |

	:::note
	A [`Mapper`](/api/Mapper) cannot track updates to
	components. [`World:getMapper`](#getMapper) throws an error when passed a `Query`
	containing a `withUpdated` field.
	:::

	### Using queries

	Methods like [`Reactor:each`](/api/Reactor#each) and [`Mapper:map`](/api/Mapper#map)
	take callbacks that are passed an entity and its components. The components go in a
	specific order: first the components from `withAll`, then the components from
	`withUpdated`, and finally the components from `withAny`. The order of the fields
	in `Query` has no effect on this - dictionaries don't have a defined order in Lua!
	Here are some example signatures using made-up components:

	```lua
	local world = Anatta.getWorld("TheOverworld")
	local components = world.components
	local registry = world.registry

	local Ascendant = components.Ascendant
	local Blessed = components.Blessed
	local Human = components.Human
	local Immortal = components.Immortal
	local Magicka = components.Magicka

	local thePowerful = world:getMapper({
		withAll = { Human, Blessed },
		withAny = { Magicka },
	})

	thePowerful:map(function(entity, human, blessed, magicka)
		return human, blessed
	end)

	local demigods = world:getReactor({
		withUpdated = { Blessed },
		withAll = { Human, Immortal },
	})

	demigods:each(function(entity, human, immortal, blessed)
	end)

	local ascendantDivineBeings = world:getReactor({
		without = { Human },
		withAny = { Magicka },
		withAll = { Blessed, Immortal },
		withUpdated = { Ascendant },
	})

	ascendantDivineBeings:each(function(entity, blessed, immortal, ascendant, magicka)
	end)
	```

	:::warning
	Sometimes we define "tag" components that look like this:
	```lua
	local T = require(Packages.Anatta).T

	return {
		name = "Blessed",
		type = T.none,
	}
	```
	Tag components always have a value of `nil`. That means:
	```lua
	local entity = registry:createEntity()

	registry:addComponent(entity, Blessed)

	assert(registry:getComponent(entity, Blessed) == nil, "Tag components are equal to nil!")
	```
	And also:
	```lua
	world:getMapper({
		withAll = { Blessed },
	}):map(function(entity, blessed)
		assert(blessed == nil, "Tag components are equal to nil!")
	end)
	```

	The correct way to check for the existence of tag components (and in general) is with
	[`Registry:entityHas`](/api/Registry#entityHas) or
	[`Registry:entityHasAny`](/api/Registry#entityHasAny).
	:::
]=]
local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Core.Constants)
local Dom = require(script.Parent.Dom)
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

local ENTITY_TAG_NAME = Constants.EntityTagName
local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

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
				util.jumpAssert(rawget(self, componentName) ~= nil, ErrInvalidComponentDefinition, componentName)
			end,
		}),
		registry = registry,
		_reactorSystems = {},
	}, World)
end

function World:fromPrefab(prefab: Model)
	assert(prefab.PrimaryPart ~= nil, "Prefabs must have a PrimaryPart")

	local registry = self.registry
	local entityRewriteMap = {}
	local linkedInstances = {}

	local function rewriteEntityRefs(typeDefinition, value)
		if typeDefinition.typeName == "entity" then
			return entityRewriteMap[value] or value
		elseif typeDefinition.typeName == "strictInterface" then
			for field, fieldType in pairs(typeDefinition.typeParams[1]) do
				value[field] = rewriteEntityRefs(fieldType, value[field])
			end
		elseif typeDefinition.typeName == "strictArray" then
			for field, fieldType in ipairs(typeDefinition.typeParams) do
				value[field] = rewriteEntityRefs(fieldType, value[field])
			end
		end

		return value
	end

	local primaryEntity

	for _, descendant in ipairs(prefab:GetDescendants()) do
		if not CollectionService:HasTag(descendant, ENTITY_TAG_NAME) then
			continue
		end

		local entity = registry:createEntity()
		local originalEntity = descendant:GetAttribute(ENTITY_ATTRIBUTE_NAME)

		if descendant == prefab.PrimaryPart then
			primaryEntity = entity
		end

		linkedInstances[descendant] = entity
		entityRewriteMap[originalEntity] = entity
	end

	for linkedInstance, entity in pairs(linkedInstances) do
		for componentDefinition in pairs(registry._pools) do
			if not CollectionService:HasTag(linkedInstance, componentDefinition.name) then
				continue
			end

			local success, originalEntity, component = Dom.tryFromAttributes(linkedInstance, componentDefinition)

			if not success then
				warn(
					("Failed attribute validation for %s while building the prefab %s: %s"):format(
						prefab:GetFullName(),
						componentDefinition.name,
						originalEntity
					)
				)
				continue
			end

			local rewrittenComponent = rewriteEntityRefs(componentDefinition.type, component)

			registry:addComponent(entity, componentDefinition, rewrittenComponent)
		end
	end

	return primaryEntity, linkedInstances
end

function World:cloneFromPrefab(prefab: Model)
	assert(prefab.PrimaryPart ~= nil, "Prefabs must have a PrimaryPart")

	local registry = self.registry
	local copiedPrefab = prefab:Clone()
	local entityRewriteMap = {}
	local linkedInstances = {}

	local function rewriteEntityRefs(typeDefinition, value)
		if typeDefinition.typeName == "entity" then
			return entityRewriteMap[value] or value
		elseif typeDefinition.typeName == "strictInterface" then
			for field, fieldType in pairs(typeDefinition.typeParams[1]) do
				value[field] = rewriteEntityRefs(fieldType, value[field])
			end
		elseif typeDefinition.typeName == "strictArray" then
			for field, fieldType in ipairs(typeDefinition.typeParams) do
				value[field] = rewriteEntityRefs(fieldType, value[field])
			end
		end

		return value
	end

	local primaryEntity

	for _, descendant in ipairs(copiedPrefab:GetDescendants()) do
		if not CollectionService:HasTag(descendant, ENTITY_TAG_NAME) then
			continue
		end

		local entity = registry:createEntity()
		local originalEntity = descendant:GetAttribute(ENTITY_ATTRIBUTE_NAME)

		if descendant == copiedPrefab.PrimaryPart then
			primaryEntity = entity
		end

		linkedInstances[descendant] = entity
		entityRewriteMap[originalEntity] = entity
	end

	for linkedInstance, entity in pairs(linkedInstances) do
		for componentDefinition in pairs(registry._pools) do
			if not CollectionService:HasTag(linkedInstance, componentDefinition.name) then
				continue
			end

			local success, originalEntity, component = Dom.tryFromAttributes(linkedInstance, componentDefinition)

			if not success then
				warn(
					("Failed attribute validation for %s while building the prefab %s: %s"):format(
						prefab:GetFullName(),
						componentDefinition.name,
						originalEntity
					)
				)
				continue
			end

			local rewrittenComponent = rewriteEntityRefs(componentDefinition.type, component)

			registry:addComponent(entity, componentDefinition, rewrittenComponent)

			local _, rewrittenAttributeMap = Dom.tryToAttributes(
				linkedInstance,
				entity,
				componentDefinition,
				rewrittenComponent
			)

			for attributeName, value in pairs(rewrittenAttributeMap) do
				if typeof(value) == "number" then
					linkedInstance:SetAttribute(attributeName, value)
				end
			end
		end
	end

	return copiedPrefab, primaryEntity, linkedInstances
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
			util.jumpAssert(self.registry:isComponentDefined(definintion), ErrInvalidComponentDefinition, definintion)
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
function World:getReactor(query)
	local withAll = query.withAll or {}
	local withUpdated = query.withUpdated or {}
	local withAny = query.withAny or {}

	util.jumpAssert(#withUpdated <= 32, ErrTooManyUpdated)
	util.jumpAssert(#withAll > 0 or #withUpdated > 0 or #withAny > 0, ErrReactorsNeedComponents)

	for _, components in pairs(query) do
		for _, definition in ipairs(components) do
			util.jumpAssert(self.registry:isComponentDefined(definition), ErrInvalidComponentDefinition, definition)
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
