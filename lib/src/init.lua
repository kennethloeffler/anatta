--[=[
	@class Anatta

	`Anatta` is the main entry point to the library and is used to manage
	[`World`](/api/World)s.
]=]

local Dom = require(script.Dom)
local T = require(script.Core.T)
local Types = require(script.Types)
local World = require(script.World)
local util = require(script.util)

local ErrWorldAlreadyExists = 'A world named "%s" already exists'
local ErrWorldDoesntExist = 'No world named "%s" exists'

--- @interface ComponentDefinition
--- @within Anatta
--- .name string
--- .type TypeDefinition
--- .description string?
--- A named [`TypeDefinition`](/api/T#TypeDefinition) with an optional description.

local Worlds = {}

--[=[

	Creates a new [`World`](World). If the second argument is a list of
	[`ComponentDefinition`](#ComponentDefinition)s, calls
	[`Registry:defineComponent`](/api/Registry#defineComponent) on each member of the
	list. Otherwise, if the second argument is an `Instance`, require all of the
	`Instance`'s `ModuleScript` descendants and attempt to define each result.

	@function createWorld
	@within Anatta
	@param namespace string
	@param componentDefinitions {[string]: ComponentDefinition} | Instance
	@return World
]=]
local function createWorld(namespace, componentDefinitions)
	local definitions = {}

	util.jumpAssert(not Worlds[namespace], ErrWorldAlreadyExists, namespace)

	if typeof(componentDefinitions) == "table" then
		for _, definition in pairs(componentDefinitions) do
			util.jumpAssert(Types.ComponentDefinition(definition))
			table.insert(definitions, definition)
		end
	elseif typeof(componentDefinitions) == "Instance" then
		local instance = componentDefinitions

		componentDefinitions = {}

		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("ModuleScript") and not descendant.Name:find("%.spec$") then
				local definition = require(descendant)

				if Types.ComponentType(definition) then
					table.insert(definitions, definition)
				end
			end
		end
	end

	local world = World.new(definitions)
	Worlds[namespace] = world

	return world
end

--[=[
	Returns the [`World`](World) with the given namespace.

	@function getWorld
	@within Anatta
	@param namespace string
	@return World
]=]
local function getWorld(namespace, script)
	local world = Worlds[namespace]

	util.jumpAssert(world, ErrWorldDoesntExist, namespace)

	if script then
		world:addSystem(script)
	end

	return world
end

return {
	Dom = Dom,
	T = T,

	createWorld = createWorld,
	getWorld = getWorld,
}
