--[=[
	@class Anatta
]=]

local Dom = require(script.Dom)
local RemoteEntityMap = require(script.RemoteEntityMap)
local Registry = require(script.Registry)
local System = require(script.System)
local TypeDefinition = require(script.Core.TypeDefinition)
local Types = require(script.Parent.Types)
local World = require(script.World)
local util = require(script.util)

local ErrWorldAlreadyExists = 'A world named "%s" already exists'
local ErrWorldDoenstExist = 'No world named "%s" exists'

local Worlds = {}

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

local function getWorld(namespace)
	local world = Worlds[namespace]

	util.jumpAssert(world, ErrWorldDoenstExist:format(world))

	return world
end

return {
	createWorld = createWorld,
	getWorld = getWorld,

	Dom = Dom,
	Registry = Registry,
	RemoteEntityMap = RemoteEntityMap,
	System = System,
	t = TypeDefinition,
}
