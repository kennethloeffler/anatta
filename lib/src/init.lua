--[=[
	@class Anatta

	The main entry point for the library.
]=]

local Dom = require(script.Dom)
local Registry = require(script.Registry)
local System = require(script.System)
local TypeDefinition = require(script.Core.TypeDefinition)
local Types = require(script.Parent.Types)
local World = require(script.World)
local util = require(script.util)

local ErrWorldAlreadyExists = 'A world named "%s" already exists'
local ErrWorldDoenstExist = 'No world named "%s" exists'

local Worlds = {}

--[=[
	Creates a new [`World`](World) and calls
	[`Registry:defineComponent`](Registry#defineComponent) on the given
	[`ComponentDefinition`](#ComponentDefinition)s.

	@function createWorld
	@within Anatta
	@param namespace string
	@param componentDefinitions {ComponentDefinition}
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

				util.jumpAssert(Types.ComponentType(componentDefinition))

				table.insert(componentDefinitions, componentDefinition)
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

	util.jumpAssert(world, ErrWorldDoenstExist:format(world))

	world:addSystem(script)

	return world
end

return {
	createWorld = createWorld,
	getWorld = getWorld,

	Dom = Dom,
	Registry = Registry,
	System = System,
	t = TypeDefinition,
}
