--[[
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
THIS CLASS IS A SINGLETON! Multiple instances of EntityManager in the same environment may produce unexpected behavior.

EntityManager.lua

	EntityManager is a class used to manage the state of entities, components, and their relationships. Some methods are not available depending on if this class is loaded on a client
	or a server; if this is the case, it is indicated in the API reference below with a "Client" or "Server" tag.

	Constructor:
	
		n/a - constructs one and only one EntityManager when require() is first called on this module
		
	Public
	
		Member functions
			
			void EntityManager:StepSystem(systemName, float deltaT)
				Description: Runs the system matching systemName once
		
			T EntityManager:GetComponent(Instance entity, string componentType)
				Description: returns the component matching componentType for entity, if it 1) is a valid entity, and 2) has componentType
				
			T EntityManager:GetAllComponentsOfType(string componentType) 
				Description: returns an array containing all components matching componentType
					
			T EntityManager:AddComponent(Instance entity, string componentType, T paramList) 
				Descripton: adds componentType to entity with parameters contained in paramList (if entity is not a valid entity, it will be assigned when this functon is called)
			
			void EntityManager:KillComponent(Instance entity, string componentType)
				Descripton: removes component from entity if 1) entity has componentType, and 2) entity is a valid entity

			void EntityManager:KillEntity(Instance entity)
				Descripton: kills entity assigned to entity if entity is a valid entity
			
			[Client] void EntityManager:RequestAddComponent(Instance entity, string componentType, T paramList)
				Description: sends a request to the server to create componentType belonging to entity with parameters defined by paramList
							
			[Server] void EntityManager:LoadForPlayer(Instance instanceToLoad, Player player)
				Description: Loads instanceToLoad and all ts associated entities for player
			
			[Server] void EntityManager:KillEntityForPlayer(Instance entity, Player player)
				Description: removes entity for player if 1) entity is a valid entity, and 2) player has entity loaded
			
			[Server] void EntityManager:UpdateComponentForPlayer(Instance entity, Player player, string componentType, T paramList)
				Description: updates the state of a component belonging to entity with paramList for player if 1) entity is a valid entity, 2) entity has componentType, and 3) player has entity loaded
			
			[Server] void EntityManager:KillComponentForPlayer(Instance entity, Player player, string componentType)
				Description: Removes component belonging to entity for player if 1) entity is a valid entity, 2) entity has componentType, and 3) player has entity loaded

		Member variables
			
			RBXScriptSignal EntityManager.PlayerAdded
				Description: Fires when a new client has been added to the server, i.e.
				
					EntityManager.PlayerAdded:connect(function(Player player)
						--do stuff with player
					end
				
	Private
	
		Member functions
		
			int EntityManager:_createGUIDForInstance(instance)
				Description: gets a new valid EntityId for instance when (used for entity initialization)
			
			int EntityManager:_createEntity(instance)
				Description: creates a new EntityId for instance
				
			int EntityManager:_getEntity(instance)
				Description: gets the EntityId for instance
		
		Member variables
			int EntityManager._totalEntities
				Description: the total amount of entities managed by this EntityManager
			
			T EntityManager._freedGUIDs
				Description: an array containing cached GUIDs available for re-use
				
			T EntityManager._entityMap
				Description: a dictionary which ties loaded entities to their components. It is structured like so:
					string entity1 = {int componentId1 = true, int componentId2 = true, int componentId3 = true . . . },
					string entity1 = {int componentId1 = true, int componentId2 = true, int componentId3 = true . . . },
					string entity1 = {int componentId1 = true, int componentId2 = true, int componentId3 = true . . . },
						.
						.
						.
			T EntityManager._componentMap
				Description: an array which lists all loaded components by componentId:
					int componentId1 = {string entity1 = T component, string entity2 = T component, string entity3 = T component, . . . },
					int componentId2 = {string entity1 = T component, string entity2 = T component, string entity3 = T component, . . . },
					int componentId3 = {string entity1 = T component, string entity2 = T component, string entity3 = T component, . . . },
						.
						.
						.
			
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
--]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Component = require(script.Parent.Component)

local IsStudio = RunService:IsStudio()
local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()
local IsRunMode = RunService:IsRunMode()

local EntityManager = {}
EntityManager.__index = EntityManager

function EntityManager.new() -- constructor is just here for readability - don't call this
	local self = setmetatable({}, EntityManager)

	self._totalEntities = 0
	self._entityMap = {}
	self._componentMap = {}
	self._freedGUIDs = {}
	
	local componentAddedEvent = Instance.new("BindableEvent")
	self._componentAddedEvent = componentAddedEvent
	
	if IsClient and not IsServer then
		
		self._entityUpdater = game.Players.LocalPlayer.PlayerGui:WaitForChild("entityUpdater" .. tostring(game.Players.LocalPlayer.UserId))
		self._entityLoader = game.Players.LocalPlayer.PlayerGui:WaitForChild("entityLoader" .. tostring(game.Players.LocalPlayer.UserId))
		
		self:_setupClient()
		
	elseif IsServer and not IsClient then
		
		self._clientEntities = {}
		
		local clientRequestEvent = Instance.new("BindableEvent")
		self._clientRequestEvent = clientRequestEvent
		
		local playerAddedEvent = Instance.new("BindableEvent")
		self._playerAddedEvent = playerAddedEvent
		self.PlayerAdded = playerAddedEvent.Event
		
		self:_setupEntityComponentMaps()
		
	end
		
	return self
end

function EntityManager:_createGUIDForInstance(instance)
	local GUID = Instance.new("StringValue")
	GUID.Name = "GUID"
	GUID.Parent = instance
	self._totalEntities = self._totalEntities + 1
	if #self._freedGUIDs > 0 then
		GUID.Value = self._freedGUIDs[#self._freedGUIDs]
		self._freedGUIDs[#self._freedGUIDs] = nil
	else
		GUID.Value = HttpService:GenerateGUID(false)
	end
	return GUID.Value
end

function EntityManager:_createEntity(instance)
	local GUID = self:_createGUIDForInstance(instance)
	CollectionService:AddTag(instance, "entity")
	self._entityMap[GUID] = {} -- TODO: minimize rehashes by filling this table with n bools, where n is the number of unique ComponentTypes 
	return GUID
end

function EntityManager:_getEntity(instance)
	if CollectionService:HasTag(instance, "entity") then
		return instance.GUID.Value
	end
end

function EntityManager:AddComponent(instance, componentType, paramList, isStudio, isPlugin)
	local entity = self:_getEntity(instance) or self:_createEntity(instance)
	local component = Component.new(instance, componentType, paramList, isStudio, isPlugin)
	local componentId = component._componentId
	if self._componentMap[componentId] == nil then 
		self._componentMap[componentId] = {} 
	end
	if self._entityMap[entity] == nil then
		self._entityMap[entity] = {}
	end
	self._entityMap[entity][componentId] = true
	self._componentMap[componentId][entity] = component
	self._componentAddedEvent:Fire(componentId, instance)
	return component, entity
end

function EntityManager:KillEntity(instance)
	local entity = self:_getEntity(instance)
	if not entity then
		error(instance.Name .. " is not an entity")
	end
	for componentId in pairs(self._entityMap[entity]) do
		self._componentMap[componentId][entity] = nil
	end
	if instance then instance:Destroy() end
	self._entityMap[entity] = nil
	self._freedGUIDs[#self._freedGUIDs + 1] = entity
end

function EntityManager:KillComponent(instance, componentType)
	local componentId = Component:_getComponentIdFromType(componentType)
	local entity = CollectionService:HasTag(instance, "entity")
	if not entity then
		error(instance.Name .. " is not an entity")
	end
	if not componentId then 
		error(componentType .. " is not a valid ComponentType")
	end
	local GUID = self:_getEntity(instance)
	self._entityMap[GUID][componentId] = nil
	self._componentMap[componentId][GUID] = nil
end

function EntityManager:GetComponent(instance, componentType)
	local componentId = Component:_getComponentIdFromType(componentType)
	local entity = CollectionService:HasTag(instance, "entity")
	if not entity then
		error(instance.Name .. " is not an entity")
	end
	if not componentId then 
		error(componentType .. " is not a valid ComponentType")
	end
	return self._componentMap[componentId][instance.GUID.Value]
end

function EntityManager:GetAllComponentsOfType(componentType)
	local componentId = Component:_getComponentIdFromType(componentType)
	if not componentId then
		error(componentType .. " is not a valid ComponentType")
	else
		return self._componentMap[componentId] or {}
	end
end

function EntityManager:GetComponentAddedSignal(componentType, instance)
	local componentId = Component:_getComponentIdFromType(componentType)
	local entity = instance and self:_getEntity(instance) or nil
	if not componentId then 
		error(componentType .. " is not a valid ComponentType")
	end
	local BindableEvent = Instance.new("BindableEvent")
	self._componentAddedEvent.Event:connect(function(addedComponentId, parentInstance)
		local GUID = entity ~= nil and self:_getEntity(parentInstance) or nil
		if addedComponentId == componentId and GUID == entity then
			BindableEvent:Fire(parentInstance)
		end
	end)
	return BindableEvent.Event, BindableEvent
end

function EntityManager:LoadForPlayer(instance, player)
	
	local function getEntitiesForInstance(instance)
		if not self._clientEntities[player.UserId] then
			self._clientEntities[player.UserId] = {}
		end
		local clientEntityMap = {}
		local clientComponentMap = {}
		for _, entity in pairs(CollectionService:GetTagged("entity")) do
			local GUID = entity.GUID.Value
			if entity == instance or entity:IsDescendantOf(instance) then
				clientEntityMap[GUID] = {}
				self._clientEntities[player.UserId][GUID] = true 
				for componentId in pairs(self._entityMap[GUID]) do
					local componentIdString = tostring(componentId)
					if not clientComponentMap[componentIdString] then
						clientComponentMap[componentIdString] = {}
					end
					clientComponentMap[componentIdString][GUID] = setmetatable(self._componentMap[componentId][GUID], nil)
					clientEntityMap[GUID][componentIdString] = true
				end
			end
		end
		return clientEntityMap, clientComponentMap
	end
	
	if IsServer then
		local clientEntityMap, clientComponentMap = getEntitiesForInstance(instance)
		local newInstance = instance:Clone()
		local entityLoader = player.PlayerGui["entityLoader" .. tostring(player.UserId)]
		newInstance.Parent = player.PlayerGui
		entityLoader:InvokeClient(player, 0, newInstance, clientEntityMap, clientComponentMap)
		newInstance:Destroy()
	else
		error("LoadForPlayer cannot be used on the client")
	end
end

function EntityManager:KillComponentForPlayer(instance, player, componentType)
	local componentId = Component:_getComponentIdFromType(componentType)
	local entity = instance:_getEntity(instance)
	if not entity then
		error(instance.Name .. " is not an entity")
	end
	if not componentId then 
		error(componentType .. " is not a valid ComponentType")
	end
	if not IsServer then
		error("KillComponentForPlayer cannot be used on the client")
	end
	if self._clientEntities[player.UserId][entity] then -- don't need to fire event if client doesn't have entity loaded
		local entityUpdater = player.PlayerGui["entityUpdater" .. tostring(player.UserId)]
		entityUpdater:FireClient(2, player, entity, componentId) -- firing with code 2 - killing a component
	end
end

function EntityManager:UpdateComponentForPlayer(instance, player, componentType, paramList)
	local componentId = Component:_getComponentIdFromType(componentType)
	local entity = instance:_getEntity(instance)
	if not entity then
		error(instance.Name .. " is not an entity")
	end
	if not componentId then 
		error(componentType .. " is not a valid ComponentType")
	end
	if not IsServer then
		error("UpdateComponentForPlayer cannot be used on the client")
	end
	if self._clientEntities[player.UserId][entity] then -- don't need to fire event if client doesn't have entity loaded
		local entityUpdater = player.PlayerGui["entityUpdater" .. tostring(player.UserId)]
		local t = {}
		for paramName, value in pairs(paramList) do
			local paramId = Component:_getParamIdFromName(paramName, componentId)
			t[paramId] = value
		end
		entityUpdater:FireClient(0, player, entity, componentId, t) -- firing with code 0 - updating a component
	end
end

function EntityManager:KillEntityForPlayer(instance, player)
	local entity = instance:_getEntity(instance)
	if not entity then
		error(instance.Name .. " is not an entity")
	end
	if not IsServer then
		error("KillEntityForPlayer cannot be used on the client")
	end
	if self._clientEntities[player.UserId][entity] then -- don't need to fire event if client doesn't have entity loaded
		local entityUpdater = player.PlayerGui["entityUpdater" .. tostring(player.UserId)]
		entityUpdater:FireClient(1, player, entity) -- firing with code 1 - killing an entity
	end
end

function EntityManager:GetClientRequestSignal(requestType, componentType, instance)
	local entity = self:_getEntity(instance)
	local componentId = Component:_getComponentIdFromType(componentType)
	if not entity then 
		error(instance.Name .. " is not an entity")
	end
	if not componentId then
		error(componentType .. " is not a valid ComponentType")
	end
	if not IsServer then
		error("GetClientRequestSignal cannot be used on the client")
	end
	local BindableEvent = Instance.new("BindableEvent")
	if requestType == "AddComponent" then
		self._clientRequestEvent:connect(function(player, code, GUID, reqComponentId, paramList)
			if GUID == entity and reqComponentId == componentId and code == 0 then
				BindableEvent:Fire(player, paramList)
			end
		end)
		return BindableEvent.Event, BindableEvent
	elseif requestType == "KillComponent" then
		
	else
		error(requestType .. " is not a valid RequestType")
	end
end 

function EntityManager:RequestAddComponent(instance, componentType, paramList)
	if IsClient then
		local entity = self:_getEntity(instance)
		if entity then
			local componentId = Component:_getComponentIdFromType(componentType)
			if componentId then
				local t = {}
				for index, value in pairs(paramList) do
					local paramId = Component:_getParamIdFromName(index)
					if paramId then
						t[paramId] = value
					end
				end
				self._entityUpdater:FireServer(entity, componentId, t)
			end
		end
	end
end

function EntityManager:_setupEntityComponentMaps()
										  					
	if IsServer then
		
		local function createParamList(componentRef)
			local t = {}
			local c = componentRef:GetChildren()
			for i = 1, #c do
				if c[i]:IsA("ValueBase") then
					t[c[i].Name] = c[i].Value
				end
			end
			return t
		end
		
		local assignedInstances = CollectionService:GetTagged("entity")
		local componentTags = CollectionService:GetTagged("component")
		
		-- two TIGHT loops - all the setup we really need ...
		local mapBuildTime = tick()
		for _, instance in pairs(assignedInstances) do 
			local entity = self:_getEntity(instance)
			self._entityMap[entity] = {}
		end
		
		for _, componentRef in pairs(componentTags) do
			self:AddComponent(componentRef.Parent, componentRef.Name, createParamList(componentRef), IsStudio)
			if IsStudio == false or IsRunMode == true then -- don't need these ValueBase instances floating around in memory anymore
				componentRef:Destroy()
			end
		end
		
		-- ... except for handling networking things
		if IsStudio == false or IsRunMode == true then
			game.Players.PlayerAdded:connect(function(player)
				local entityLoader = Instance.new("RemoteFunction")
				entityLoader.Name = "entityLoader" .. tostring(player.UserId)
				entityLoader.Parent = player.PlayerGui
				local entityUpdater = Instance.new("RemoteEvent")
				entityUpdater.Name = "entityUpdater" .. tostring(player.UserId)
				entityUpdater.Parent = player.PlayerGui
				entityUpdater.OnServerEvent:connect(function(player, code, GUID, componentId, paramList)
					self._clientRequestEvent:Fire(player, code, GUID, componentId, paramList)
				end)
				self._playerAddedEvent:Fire(player)
			end)
		end
	else
		error("_setupEntityComponentMaps cannot be used on the client")
	end
end

function EntityManager:_setupClient()
		
	if IsClient then
		
		local function createParamList(component, componentId)
			local t = {}
			for paramId in pairs(component) do
				local paramName = Component:_getParamNameFromId(paramId, componentId)
				t[paramName] = component[paramId]
			end
			return t
		end
			
		self._entityLoader.OnClientInvoke = function(code, instance, entityMap, componentMap) -- server wants to add an entity (or entities) to this client
			local newInstance = instance:Clone()
			newInstance.Parent = game.Workspace
			-- all we need are some TIGHT loops
			for _, entity in pairs(CollectionService:GetTagged("entity")) do 
				if entity == newInstance or entity:IsDescendantOf(newInstance) then
					local GUID = entity.GUID.Value
					for componentIdString in pairs(entityMap[GUID]) do
						local componentId = tonumber(componentIdString)
						self:AddComponent(entity, componentId, createParamList(componentMap[componentIdString][GUID], componentId))
					end
				end
			end
			return	
		end
		
		self._entityUpdater.OnClientEvent:connect(function(code, GUID, componentId, paramList)
			if code == 0 then -- server wants to update the state of a component on this client
				for paramId in pairs(paramList) do
					self._componentMap[componentId][GUID][paramId] = paramList[paramId]
				end
			elseif code == 1 then -- server wants to kill an entity on this client
				self:KillEntity(GUID)
			elseif code == 2 then -- server wants to kill a component on this client
				self:KillComponent(GUID, componentId)
			end
		end)
			
	else
		error("_setupClient cannot be used on the server")	
	end
end

function EntityManager:StepSystem(systemName, deltaT)
	local system
	if IsClient then
		system = require(game.ReplicatedStorage.WorldSmith.ClientSystems[systemName])
		system(self, deltaT)
	elseif IsServer and not IsStudio then
		system = require(game.ServerScriptService.WorldSmith.ServerSystems[systemName])
		system(self, deltaT)
	end
end

function EntityManager:Destroy()
	self = nil
end

function EntityManager:_getComponentDesc() -- used by plugin
	return Component:_getComponentDesc()
end

function EntityManager:_getComponentIdFromType(componentType)
	return Component:_getComponentIdFromType(componentType)
end

function EntityManager:_getParamNameFromId(paramId, componentId)
	return Component:_getParamNameFromId(paramId, componentId)
end

return EntityManager.new()