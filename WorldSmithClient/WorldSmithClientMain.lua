--[[
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
THIS CLASS IS A SINGLETON! Multiple instances of WorldSmithClientMain may produce unexpected behavior.

WorldSmithClientMain.lua

Constructor:
	n/a - constructs one and only one WorldSmithClientMain instance when require() is first called on this module

Member functions:
	Public:
		(none)
	Private: 
		WorldSmithClientMain:_setupEntityComponentMap() - generates the entity-component and component-entity maps for the client, which are accessible by systems
		WorldSmithClientMain:_initializeSystems() - starts all clientside systems defined in game.ReplicatedStorage.WorldSmithClient.Systems
		
Member variables:
	Public:
		(none)
	Private: 
		self._entityComponentMap - a dictionary which ties loaded entities to their components. It is structured like so:
			Instance entity1 = {Folder component1, Folder component2, Folder component3, . . . },
			Instance entity2 = {Folder component1, Folder component2, Folder component3, . . . },
			Instance entity3 = {Folder component1, Folder component2, Folder component3, . . . },
					.
					.
					.
		self._componentEntityMap - a dictionary which lists all loaded components by type:
			string componentName1 = {Folder component1, Folder component2, Folder component3, . . . },
			string componentName2 = {Folder component1, Folder component2, Folder component3, . . . },
			string componentName3 = {Folder component1, Folder component2, Folder component3, . . . },
					.
					.
					.
		
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
--]]


local CollectionService = game:GetService("CollectionService")
local Utilities = require(script.Parent.WorldSmithClientUtilities)

local WorldSmithClientMain = {}
WorldSmithClientMain.__index = WorldSmithClientMain

function WorldSmithClientMain.new()
	local self = setmetatable({}, WorldSmithClientMain)
	
	self._entityComponentMap = {}
	self._componentEntityMap = {}
	
	repeat wait() until game:IsLoaded() == true
	
	self:_setupEntityComponentMap()
	self:_initializeSystems()
	
	return self
end

function WorldSmithClientMain:_setupEntityComponentMap()
	print("WorldSmithClientMain: building clientside entity component maps...")
	local mapBuildTime = tick()
	
	CollectionService:GetInstanceAddedSignal("entity"):connect(function(entity)
		self._entityComponentMap[entity] = {}
	end)
	
	CollectionService:GetInstanceRemovedSignal("entity"):connect(function(entity)
		self._entityComponentMap[entity] = nil
	end)
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		local entity = component.Parent
		if self._componentEntityMap[component.Name] == nil then 
			self._componentEntityMap[component.Name] = {}
		end
		if self._entityComponentMap[entity] then
			self._entityComponentMap[entity][#self._entityComponentMap[entity] + 1] = component
			self._componentEntityMap[component.Name][#self._componentEntityMap[component.Name] + 1] = component
		end
	end)
	
	CollectionService:GetInstanceRemovedSignal("component"):connect(function(component)
		for _, v in ipairs(self._componentEntityMap[component.Name]) do
			if v == component then
				self._componentEntityMap[component.Name][v] = nil
			end
		end
	end)
	
	local assignedInstances = CollectionService:GetTagged("entity")
	local componentTags = CollectionService:GetTagged("component")
	
	for _, entity in pairs(assignedInstances) do
		self._entityComponentMap[entity] = {}
		for i, v in ipairs(entity:GetChildren()) do
			if v:IsA("Folder") then
				self._entityComponentMap[entity][#self._entityComponentMap[entity] + 1] = v
			end
		end
	end
	
	for _, component in pairs(componentTags) do
		if self._componentEntityMap[component.Name] == nil then self._componentEntityMap[component.Name] = {} end
		self._componentEntityMap[component.Name][#self._componentEntityMap[component.Name] + 1] = component
	end
	
	print("WorldSmithClientMain: took " .. tick() - mapBuildTime .. " seconds to build clientside entity component maps")
end

function WorldSmithClientMain:_initializeSystems()
	print("WorldSmithClientMain: initialzing clientside systems...")
	local mapBuildTime = tick()
	for _, system in pairs(script.Parent.Systems:GetChildren()) do
		local sys = require(system)
		spawn(function()
			sys.Start(self._componentEntityMap, self._entityComponentMap)
		end)
	end
	print("WorldSmithClientMain: took " .. tick() - mapBuildTime .. " seconds to start clientside systems")
end


return WorldSmithClientMain.new()
