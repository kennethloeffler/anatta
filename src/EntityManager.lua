-- EntityManager.lua
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ComponentDesc = require(script.Parent.ComponentDesc)
local ComponentFactory = require(script.Parent.ComponentFactory)
local WSAssert = require(script.Parent.WSAssert)

local SERVER = RunService:IsServer() and not RunService:IsClient()
local STUDIO = RunService:IsStudio()
local RUNMODE = RunService:IsRunMode()

local bExtract = bit32.extract
local bReplace = bit32.replace

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
local EntityFilters = {}
local SystemEntities = {}
local Systems = {}

-- bitfield setter
local function setComponentBitForEntity(entity, componentId, value)
	local offset = math.ceil(componentId * 0.03125) -- componentId / 32
	local bitField = EntityMap[entity][0][offset]
	EntityMap[entity][0][offset] = bReplace(bitField, value, componentId - 1 - (32 * (offset - 1)))
end

-- bitfield getter
local function getComponentBitForEntity(entity, componentId)
	local offset = math.ceil((componentId * 0.03125)) -- comoponentId / 32
	local bitField = EntityMap[entity][0][offset]
	return bExtract(bitField, componentId - 1 - (32 * (offset - 1))) == 1
end

local function filterEntity(instance)
	local entity = EntitiesByInstance[instance]
	if not entity then
		return
	end
	local entityBitFields = EntityMap[entity][0]
	for systemId, bitFields in ipairs(EntityFilters) do
		-- don't really want to do a loop here
		local bitFieldsMatch = bitFields[1] == entityBitFields[1] and bitFields[2] == entityBitFields[2] and bitFields[3] == entityBitFields[3] and bitFields[4] == entityBitFields[4]
		if not bitFieldsMatch then
			SystemEntities[systemId][instance] = nil
		else
			SystemEntities[systemId][instance] = true
		end
	end
end

---Gets an available GUID and attaches it to instance
-- @param instance
-- @return the new GUID
local function getNewGuid(instance)
	local guid
	local numFreedGuids = #FreedGuidCache
	if numFreedGuids > 0 then
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

local function doReorder(componentId, parentEntitiesMap)

	if not next(parentEntitiesMap) then
		return
	end

	local componentList = ComponentMap[componentId]
	local keptComponentOffset = 1
	for _, component in ipairs(componentList) do
		local entity = component._entity
		local componentOffset = EntityMap[entity][componentId]
		local instance = component.Instance
		if not parentEntitiesMap[entity] then
			if componentOffset ~= keptComponentOffset then
				-- swap !
				componentList[keptComponentOffset] = componentList[componentOffset]
				EntityMap[entity][componentId] = keptComponentOffset
				componentList[componentOffset] = nil					
			end
			keptComponentOffset = keptComponentOffset + 1
		else
		   	-- kill !
			componentList[componentOffset] = nil
			EntityMap[entity][componentId] = nil
			parentEntitiesMap[entity] = nil
			setComponentBitForEntity(entity, componentId, 0)
			filterEntity(instance)
			if not next(EntityMap[entity]) then
				-- we dead !
				CollectionService:RemoveTag(instance, "_WSEntity")
				EntityMap[entity] = nil
				FreedGuidCache[#FreedGuidCache + 1] = entity
				TotalEntities = TotalEntities - 1
				EntitiesByInstance[instance] = nil
			end
		end
	end
end

---Iterates through the component lifetime caches and mutates entity-component maps accordingly
-- Called before each system step
local function stepComponentLifetime()
   
	for componentId, parentEntitiesMap in pairs(KilledComponents) do
		doReorder(componentId, parentEntitiesMap)
	end
	
	for i, component in ipairs(AddedComponents) do
		local componentId = component._componentId
		local componentOffset = #ComponentMap[componentId] + 1
		local entity = component._entity
		local instance = component.Instance
		EntityMap[entity][componentId] = componentOffset
		ComponentMap[componentId][componentOffset] = component
		AddedComponents[i] = nil
		setComponentBitForEntity(entity, componentId, 1)
		filterEntity(instance)
		ComponentAddedEvents[componentId]:Fire(instance)
	end
end

-- Initialization
local function initComponentDefs()
	for componentType, componentDefinition in pairs(ComponentDesc.ComponentDefinitions) do
		local componentId = componentDefinition.ComponentId
		ComponentMap[componentId] = not ComponentMap[componentId] and {}
		KilledComponents[componentId] = not KilledComponents[componentId] and {}
		ComponentRemovedEvents[componentId] = not ComponentRemovedEvents[componentId] and Instance.new("BindableEvent")
		ComponentAddedEvents[componentId] = not ComponentAddedEvents[componentId] and Instance.new("BindableEvent")
	end
end

initComponentDefs()

if plugin then
	ComponentDesc._defUpdateCallback = initComponentDefs
end

-- Public API
--------------------------------------------------------------------------------------------------------------------------------------------------
local EntityManager = {}

---Creates a new entity and associates it with instance
-- this function errors if an entity is already associated with instance
-- @param instance
-- @return The GUID, which represents the new entity
function EntityManager.AddEntity(instance)
	local typeofArg = typeof(instance)
	local entity = getNewGuid(instance)
	EntityMap[entity] = { [0] = {0, 0, 0, 0} } -- table of bitfields for fast intersection tests
	TotalEntities = TotalEntities + 1
	CollectionService:AddTag(instance, "__WSEntity")
	return entity
end

---Adds a component of type componentType to instance with parameters specified by paramMap
-- If instance does not already have an associated entity, a new entity will be created
-- If instance already has componentType, the the instance's componentType will be overwritten
-- This operation is cached - creation occurs on the RunService's heartbeat or between system steps
-- @param instance
-- @param componentType 
-- @param paramMap Table containing values of parameters that will be set for this component, indexed by parameter name
-- @return The new component object
function EntityManager.AddComponent(instance, componentType, paramMap)
	local entity = EntityManager.GetEntity(instance) or EntityManager.AddEntity(instance)
	local component = ComponentFactory(instance, entity, componentType, paramMap)
	AddedComponents[#AddedComponents + 1] = component
	return component
end

---Gets the entity associated with instance
-- If instance is not associated with an entity, this function returns nil
-- @param instance
-- @return The entity's GUID and struct
function EntityManager.GetEntity(instance)
	local guid = EntitiesByInstance[instance]
	return guid, EntityMap[guid]
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
	if componentIndex then
		return ComponentMap[componentId][componentIndex]
	end
end

---Gets the list of components of type componentType
-- If there exists no components of type componentType, this function returns an empty table
-- @param componentType
-- @return The list of component objects
function EntityManager.GetAllComponentsOfType(componentType)
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	return ComponentMap[componentId]
end

function EntityManager.ComponentAdded(componentType)
	WSAssert(typeof(componentType) == "string", "expected string")

	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	WSAssert(componentId ~= nil, "%s is not a vaiid ComponentType", componentType)
	
	local bindable = ComponentAddedEvents[componentId]
	return bindable.Event
end

function EntityManager.ComponentKilled(componentType)
	WSAssert(typeof(componentType) == "string", "expected string")

	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	WSAssert(componentId ~= nil, "%s is not a vaiid ComponentType", componentType)

	local bindable = ComponentRemovedEvents[componentId]
	return bindable.Event
end

---Removes component of type componentType from the entity associated with instance
-- If instance is not associated with an entity or instance does not have componentType, this function returns without doing anything
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
-- This operation is cached - destruction occurs on the RunService's heartbeat or between system steps
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

function EntityManager.LoadSystem(module, pluginWrapper)   
	WSAssert(typeof(module) == "Instance" and module:IsA("ModuleScript"), "expected ModuleScript")

	local system = require(module)
	
	if system.Init then
		WSAssert(typeof(system.Init) == "function", "expected function %s.Init", module.Name)

		system.Init(pluginWrapper)
	end
	
	if system.Heartbeat then
		WSAssert(typeof(system.Heartbeat) == "function", "expected function %s.Heartbeat", module.Name)

		local systemId = #Systems + 1
		Systems[systemId] = system
		
		if not system.EntityFilter then
			return
		end
			
		WSAssert(typeof(system.EntityFilter) == "table", "expected array %s.EntityFilter", module.Name)
			
		EntityFilters[systemId] = {}
		SystemEntities[systemId] = {}	
		
		for i, componentType in pairs(system.EntityFilter) do
			WSAssert(typeof(componentType) == "string" and typeof(i) == "number", "EntityFilter should be a string-valued array")
		end

		for i, componentType in ipairs(system.EntityFilter) do
			local componentId = ComponentDesc.GetComponentIdFromType(componentType)
			EntityFilters[systemId][math.ceil((componentId - 1) / 32)] = bReplace(0, 1, ((componentId - (i * 32)) - 1))
		end
	end
end

function EntityManager.StartSystems()
   
	if SystemsRunning then
		return
	end

	SystemsRunning = true

	local hasSystems = #Systems > 0 and true or nil
	local lastFrameTime = RunService.Heartbeat:Wait()
	while SystemsRunning do
		for systemId, system in ipairs(Systems) do
		   	stepComponentLifetime()
			system(SystemEntities[systemId], lastFrameTime)
		end
		if not hasSytems then
			stepComponentLifetime()
		end
		lastFrameTime = RunService.Heartbeat:Wait()
	end
end

function EntityManager.StopSystems()
	SystemsRunning = false
end

function EntityManager.Destroy()
	-- maybe overkill
	SystemsRunning = false
	for componentId in pairs(ComponentRemovedEvents) do
		ComponentRemovedEvents[componentId]:Destroy()
	end
	for componentId in pairs(ComponentAddedEvents) do
		ComponentAddedEvents[componentId]:Destroy()
	end
end

return EntityManager

