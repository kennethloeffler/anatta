-- EntityManager.lua
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(script.Parent.Component)
local WSAssert = require(script.Parent.WSAssert)

local SERVER = RunService:IsServer() and not RunService:IsClient()
local STUDIO = RunService:IsStudio()
local RUNMODE = RunService:IsRunMode()

-- Internal
--------------------------------------------------------------------------------------------------------------------------------------------------
local TotalEntities = 0
local EntityMap = {}
local ComponentMap = {}
local FreedGuidCache = {}
local KilledComponents = {}
local AddedComponents = {}
local EntitiesByInstance = {}
local ComponentAddedEvents = {}
local ComponentRemovedEvents = {}
local SystemsRunning = false
local Systems = {}

---Gets an available GUID and attaches it to instance
-- @param instance
-- @return the new GUID
local function getNewGuid(instance)
	local guid
	local numFreedGuids = #FreedGuidCache
	if numFreedGUIDs > 0 then
		guid = FreedGuidCache[numFreedGuids]
		FreedGuidCache[numFreedGuids] = nil
	else
		guid = HttpService:GenerateGUID(false)
	end
	EntitiesByInstance[instance] = guid
	return guid
end

---Adds a component to the destruction cache
-- @param entity
-- @param componentId
local function cacheComponentKilled(entity, componentId)
	KilledComponents[componentId][entity] = true
end

---Iterates through the component lifetime caches and mutates entity-component maps accordingly
-- Called after each system step and when RunService.Stepped fires
local function stepComponentLifetime()
	for componentId, parentEntitiesMap in pairs(KilledComponents) do
		if next(parentEntitiesList) then
			local componentList = ComponentMap[componentId]
			local keptComponentOffset = 1
			-- fast one-pass algorithm for reording a an array after removals
			for componentOffset = 1, #componentList do
				local entity = componentList[componentOffset]._entity
				local instance = componentList[componentOffset].Instance
				if not parentEntitiesMap[entity] then
					if componentOffset ~= keptComponentOffset then
						-- Come on baby let's do the flip! Take me by my little hand and go like this !
						componentList[keptComponentOffset] = componentList[componentOffset]
						EntityMap[entity][componentId] = keptComponentOffset
						componentList[componentOffset] = nil					
					end
					keptComponentOffset = keptComponentOffset + 1
				else
					componentList[componentOffset] = nil
					EntityMap[entity][componentId] = nil
					parentEntitiesMap[entity] = nil
					if not next(EntityMap[entity]) then
						-- no components; free this entity
						CollectionService:RemoveTag(instance, "_WSEntity")
						EntityMap[entity] = nil
						FreedGuidCache[#FreedGuidCache + 1] = entity
						TotalEntities = TotalEntities - 1
						EntitiesByInstance[instance] = nil
					end
				end
			end
		end
	end
	for i = 1, #AddedComponents do
		local component = AddedComponents[i]
		local componentId = component._componentId
		local componentOffset = #ComponentMap[componentId] + 1
		EntityMap[component._entity][componentId] = componentOffset
		ComponentMap[componentId][componentOffset] = component
		AddedComponents[i] = nil
	end
end

-- Initialization
for _, moduleScript in pairs(componentsRoot:GetChildren()) do
	local componentId = require(moduleScript)
	ComponentMap[componentId] = {}
	KilledComponents[componentId] = {}
	ComponentKilledEvents[componentId] = Instance.new("BindableEvent")
	ComponentAddedEvents[componentId] = Instance.new("BindableEvent")
end

-- Public API
--------------------------------------------------------------------------------------------------------------------------------------------------
local EntityManager = {}

---Creates a new entity and associates it with instance
-- this function errors nil if an entity is already associated with instance
-- @param instance
-- @return The GUID, which represents the new entity
function EntityManager.AddEntity(instance)
   
	WSAssert(EntitiesByInstance[instance] == nil, "%s already has an associated entity", instance.Name)
	
	local entity = getNewGuid(instance)
	EntityMap[entity] = {}
	TotalEntities = TotalEntities + 1
	CollectionService:AddTag(instance, "__WSEntity")
	return entity
end

---Adds a component of type componentType to instance with parameters specified by paramMap
-- If instance does not already have an associated entity, a new entity will be created
-- If instance already has componentType, the component will be overwritten
-- This operation is cached - creation occurs on the RunService's heartbeat or between system steps
-- @param instance
-- @param componentType 
-- @param paramMap Table containing values of parameters that will be set for this component, indexed by parameter name
-- @return The new component object
function EntityManager.AddComponent(instance, componentType, paramMap)
	local entity = EntityManager.GetEntity(instance) or EntityManager.AddEntity(instance)
	local component = Component(entity, componentType, paramMap)
	AddedComponents[#AddedComponents + 1] = component
	ComponentAddedEvents[component._componentId]:Fire(instance)
	return component
end

---Gets the entity associated with instance
-- If instance is not associated with an entity, this function returns nil
-- @param instance
-- @return The entity's GUID
function EntityManager.GetEntity(instance)
	return EntitiesByInstance[instance]
end

---Gets the component of type componentType associated with instance
-- If instance is not associated with an entity or does not have componentTpye, this function returns nil
-- @param instance
-- @param componentType
-- @return The component object of type componentType associated with instance
function EntityManager.GetComponent(instance, componentType)
	local entity = EntityManager.GetEntity(instance) 

	if not entity then
		return
	end

	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local componentIndex = EntityMap[entity][componentId]
	if componentIndex
		return ComponentMap[componentId][componentIndex]
	end
end

---Gets the list of components of type componentType
-- If there exists no components of type componentType, this function returns an empty table
-- @param componentType
-- @return The list of component objects
function EntityManager.GetAllComponentsOfType(componentType)
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	return componentMap[componentId]
end

function EntityManager.ComponentAdded(componentType)
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local bindable = ComponentAddedEvents[componentId]
	return bindable.Event
end

function EntityManager.ComponentRemoved(componentType)
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local bindable = ComponentRemovedEvents[componentId]
	return bindable.Event
end

---Removes component of type componentType from the entity associated with instance
-- If instance is not associated with an entity, this function returns without doing anything
-- This operation is cached - destruction occurs on the RunService's heartbeat or between system steps
-- @param instance
-- @param componentType
function EntityManager.KillComponent(instance, componentType)
	local entity = EntityManager.GetEntity(instance)

	if not entity then
		return
	end
	
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local componentIndex = EntityMap[entity][componentId]
	if componentIndex then
		cacheComponentKilled(entity, componentId)
		ComponentRemovedEvents[componentId]:Fire(instance)
	end
end

---Removes the entity (and by extension, all components) associated with instance
-- If instance is not associated with an entity, this function returns without doing anything
-- This operation is cached - destruction occurs when the RunService's heartbeat or between system calls
-- @param instance
function EntityManager.KillEntity(instance)
	local entity = EntityManager.GetEntity(instance)

	if not entity then
		return
	end

	for componentId in pairs(EntityMap[entity]) do
		cacheComponentKilled(entity, componentId)
	   	ComponentRemovedEvents[componentId]:Fire(instance)
	end
end

function EntityManager.FromPrefab(instance)

end

function EntityManager.LoadSystem(systemModule)
   
	WSAssert(typeof(system) == "Instance" and system:IsA("ModuleScript"), "expected ModuleScript")

	local system = require(systemModule)
	if system.Heartbeat then
		WSAssert(typeof(system.Heartbeat) == "function", "expected function %s.Heartbeat", systemModule.Name)
		Systems[#Systems + 1] = system
	end
end

function EntityManager.StartSystems()
   
	WSAssert(systemsRunning == false, "systems already started")
   
	SystemsRunning = true
	local numSystems = #systems
	local lastFrameTime = RunService.Heartbeat:Wait()
	while SystemsRunning do
		stepComponentLifetime()
		for i = 1, numSystems do
		  	Systems[i](lastFrameTime)
			stepComponentLifetime()
		end
		lastFrameTime = RunService.Heartbeat:Wait()
	end
end

function EntityManager.StopSystems()
	SystemsRunning = false
end

return EntityManager
