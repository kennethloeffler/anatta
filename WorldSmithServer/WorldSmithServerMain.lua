--[[
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
THIS CLASS IS A SINGLETON! Multiple instances of WorldSmithServerMain may produce unexpected behavior.

WorldSmithServerMain.lua

Constructor:
	n/a - constructs one and only one WorldSmithServerMain instance when require() is first called on this module

Member functions:
	Public:
		(none)
	Private: 
		WorldSmithServerMain:_setupEntityComponentMap() - generates the entity-component and component-entity maps for the server, which are accessible by systems
		WorldSmithServerMain:_initializeSystems() - starts all serverside systems defined in game.ServerScriptService.WorldSmithServer.Systems
		
Member variables:
	Public:
		(none)
	Private: 
		WorldSmithServerMain._entityComponentMap - a dictionary which ties loaded entities to their components. It is structured like so:
			Instance entity1 = {Folder component1, Folder component2, Folder component3, . . . },
			Instance entity2 = {Folder component1, Folder component2, Folder component3, . . . },
			Instance entity3 = {Folder component1, Folder component2, Folder component3, . . . },
					.
					.
					.
		WorldSmithServerMain._componentEntityMap - a dictionary which lists all loaded components by type:
			string componentName1 = {Folder component1, Folder component2, Folder component3, . . . },
			string componentName2 = {Folder component1, Folder component2, Folder component3, . . . },
			string componentName3 = {Folder component1, Folder component2, Folder component3, . . . },
					.
					.
					.
		
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
--]]

local CollectionService = game:GetService("CollectionService")

local WorldSmithUtilities = require(script.Parent.WorldSmithServerUtilities)
local Component = require(script.Parent.Component)
local ComponentInfo = require(script.Parent.ComponentInfo)

local WorldSmithServerMain = {}
WorldSmithServerMain.__index = WorldSmithServerMain

function WorldSmithServerMain.new()
	local self = setmetatable({}, WorldSmithServerMain)

	self:_buildEntityComponentMap()
	self:_initializeSystems()
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		if self._entityComponentMap[component.Parent] then
			self._entityComponentMap[component.Parent][#self._entityComponentMap[component.Parent] + 1] = component
			self._componentEntityMap[component.Name][#self._componentEntityMap[component.Name] + 1] = component
		else
			error("WorldSmith: this error should never happen")
		end
	end)
	
	CollectionService:GetInstanceRemovedSignal("component"):connect(function(component)
		for _, v in ipairs(self._componentEntityMap[component.Name]) do
			if v == component then
				self._componentEntityMap[component.Name][v] = nil
			end
		end
	end)
	
	CollectionService:GetInstanceAddedSignal("entity"):connect(function(entity)
		self._entityComponentMap[entity] = {}
	end)
	
	CollectionService:GetInstanceRemovedSignal("entity"):connect(function(entity) -- idk if this is necessary 
		self._entityComponentMap[entity] = nil
	end)
	
	return self
end

function WorldSmithServerMain:_buildEntityComponentMap()
	
	self._entityComponentMap = {}
	self._componentEntityMap = {}
	local assignedInstances = CollectionService:GetTagged("entity")
	local componentTags = CollectionService:GetTagged("component")
	
	for _, entity in pairs(assignedInstances) do
		self._entityComponentMap[entity] = {}
		for i, v in ipairs(entity:GetChildren()) do
			if v:IsA("Folder") and ComponentInfo[v.Name] then
				self._entityComponentMap[entity][#self._entityComponentMap[entity] + 1] = v
			end
		end
	end
	
	for _, component in pairs(componentTags) do
		if self._componentEntityMap[component.Name] == nil then self._componentEntityMap[component.Name] = {} end
		self._componentEntityMap[component.Name][#self._componentEntityMap[component.Name] + 1] = component
	end
	
end

function WorldSmithServerMain:_initializeSystems()
	for _, system in pairs(script.Parent.Systems:GetChildren()) do
		local sys = require(system)
		spawn(function()
			sys.Start(self._componentEntityMap, self._entityComponentMap)
		end)
	end
end

function WorldSmithServerMain:AddComponentToInstance(component, componentParameterTable, instance)
	return Component.new(instance, component, componentParameterTable)
end

return WorldSmithServerMain.new()
