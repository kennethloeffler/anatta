local CollectionService = game:GetService("CollectionService")

local WorldObject = require(game.ServerScriptService.WorldSmith.WorldObject)
local WorldObjectInfo = require(game.ServerScriptService.WorldSmith.WorldObjectInfo)

local function createArgDictionary(paramContainerChildren)
	local t = {}
	local c = paramContainerChildren
	for i, v in ipairs(c) do
		if v:IsA("ValueBase") then
			t[v.Name] = v.Value
		end
	end
	return t
end

local WorldSmithMain = {}
WorldSmithMain.__index = WorldSmithMain

function WorldSmithMain.new()
	local self = setmetatable({}, WorldSmithMain)
	
	self:_buildEntityComponentMap()
	
	for entity, componentList in pairs(self._entityComponentMap) do
		for _, component in ipairs(componentList) do
			local paramContainerChildren = component:GetChildren()
			if WorldObjectInfo[component.Name]._connectEventsFunction ~= nil then
				WorldObjectInfo[component.Name]._connectEventsFunction(createArgDictionary(paramContainerChildren), component)
			end
		end
	end
	
	CollectionService:GetInstanceAddedSignal("entity"):connect(function(entity)
		print('added entity' .. entity.Name)
		self._entityComponentMap[entity] = {}
	end)
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		print('added component' .. component.Name)
		if not self._registeredSystems[component] then
			self._registeredSystems[component] = true
			if self._entityComponentMap[component.Parent] then
				self._entityComponentMap[component.Parent][#self._entityComponentMap[component.Parent] + 1] = component
				local paramContainerChildren = component:GetChildren()
				if WorldObjectInfo[component.Name]._init ~= nil then
					WorldObjectInfo[component.Name].init(createArgDictionary(paramContainerChildren), component)
				end
				if WorldObjectInfo[component.Name]._connectEventsFunction ~= nil then
					WorldObjectInfo[component.Name]._connectEventsFunction(createArgDictionary(paramContainerChildren), component)
				end
			else
				error("WorldSmith: this error should never happen")
			end
		end
	end)
	
	return self
end

function WorldSmithMain:_buildEntityComponentMap()
	local assignedInstances = CollectionService:GetTagged("entity")
	local worldObjectTags = CollectionService:GetTagged("component")
	local t = {}
	for _, entity in pairs(assignedInstances) do
		for _, component in pairs(worldObjectTags) do
			if component.Parent == entity then
				if t[entity] == nil then t[entity] = {} end
				t[entity][#t[entity] + 1] = component
			end
		end
	end
	self._entityComponentMap = t
end

function WorldSmithMain:AddWorldObjectToInstance(worldObject, worldObjectParameterTable, instance)
	return WorldObject.new(instance, worldObject, worldObjectParameterTable)
end

return WorldSmithMain.new()