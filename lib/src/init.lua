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
	@param componentDefinitions {ComponentDefinition | Instance}
	@return World
]=]
local function createWorld(namespace, componentDefinitions)
	util.jumpAssert(not Worlds[namespace], ErrWorldAlreadyExists:format(namespace))

	if typeof(componentDefinitions) == "table" then
		util.jumpAssert(Types.ComponentDefinition)
	elseif typeof(componentDefinitions) == "Instance" then
		componentDefinitions = {}

		for _, instance in ipairs(componentDefinitions:GetDescendants()) do
			if instance:IsA("ModuleScript") and not instance.Name:find("%.spec$") then
				local componentDefinition = require(instance)

				if Types.ComponentType(componentDefinition) then
					table.insert(componentDefinitions, componentDefinition)
				end
			end
		end
	end

	local world = World.new(componentDefinitions or {})
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

	util.jumpAssert(world, ErrWorldDoesntExist:format(namespace))

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
