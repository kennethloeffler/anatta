local CollectionService = game:GetService("CollectionService")

local WorldSmithUtilities = require(script.WorldSmithServerUtilities)
local Component = require(script.Component)
local ComponentInfo = require(script.ComponentInfo)

local WorldSmithMain = {}
WorldSmithMain.__index = WorldSmithMain

function WorldSmithMain.new()
	local self = setmetatable({}, WorldSmithMain)
	
	self._registeredSystems = {}
	
	self:_buildEntityComponentMap()
	
	for entity, componentList in pairs(self._entityComponentMap) do
		for _, component in ipairs(componentList) do
			local paramContainerChildren = component:GetChildren()
			if ComponentInfo[component.Name]._connectEventsFunction ~= nil then
				ComponentInfo[component.Name]._connectEventsFunction(WorldSmithUtilities.CreateArgDictionary(paramContainerChildren), component)
			end
		end
	end
	
	CollectionService:GetInstanceAddedSignal("entity"):connect(function(entity)
		self._entityComponentMap[entity] = {}
	end)
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		if not self._registeredSystems[component] then
			self._registeredSystems[component] = true
			if self._entityComponentMap[component.Parent] then
				self._entityComponentMap[component.Parent][#self._entityComponentMap[component.Parent] + 1] = component
				WorldSmithUtilities.YieldUntilComponentLoaded(component)
				local paramContainerChildren = component:GetChildren()
				if ComponentInfo[component.Name]._init ~= nil and not component.Parent:FindFirstChild("CLONE") then
					ComponentInfo[component.Name]._init(WorldSmithUtilities.CreateArgDictionary(paramContainerChildren), component)
				end
				if ComponentInfo[component.Name]._connectEventsFunction ~= nil then
					ComponentInfo[component.Name]._connectEventsFunction(WorldSmithUtilities.CreateArgDictionary(paramContainerChildren), component)
				end
			else
				error("WorldSmith: this error should never happen")
			end
		end
	end)
	
	return self
end

function WorldSmithMain:_buildEntityComponentMap()
	
	self._entityComponentMap = {}
	self._componentEntityMap = {}
	local assignedInstances = CollectionService:GetTagged("entity")
	local componentTags = CollectionService:GetTagged("component")
	
	for _, entity in pairs(assignedInstances) do
		for _, component in pairs(componentTags) do
			if component.Parent == entity then
				if self._entityComponentMap[entity] == nil then self._entityComponentMap[entity] = {} end
				if self._componentEntityMap[component.Name] == nil then self._componentEntityMap[component.Name] = {} end
				self._entityComponentMap[entity][#self._entityComponentMap[entity] + 1] = component
				self._componentEntityMap[component.Name][#self._componentEntityMap[component.Name] + 1] = entity
			end
		end
	end
end

function WorldSmithMain:AddComponentToInstance(component, componentParameterTable, instance)
	return Component.new(instance, component, componentParameterTable)
end

return WorldSmithMain.new()