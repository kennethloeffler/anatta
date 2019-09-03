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

-- Internal
--------------------------------------------------------------------------------------------------------------------------------------------------
local EntityMap = {}
local ComponentMap = {}
local KilledComponents = {}
local AddedComponents = {}
local AddedComponentLists = {}
local KilledComponentLists = {}
local SystemsRunning = false
local EntityFilters = {}
local SystemEntities = {}
local HeartbeatSystemEntities = {}
local HeartbeatSystems = {}
local SystemsToUnload = {}

local GetComponentIdFromType = ComponentDesc.GetComponentIdFromType

local function setComponentBitForEntity(entity, componentId)
	local offset = math.ceil(componentId * 0.03125) -- componentId / 32
	local bitField = EntityMap[entity][0][offset]

	EntityMap[entity][0][offset] = bit32.bor(bitField, bit32.lshift(1, componentId - 1 - (32 * (offset - 1))))
end

local function unsetComponentBitForEntity(entity, componentId)
	local offset = math.ceil(componentId * 0.03125)
	local bitField = EntityMap[entity][0][offset]

	EntityMap[entity][0][offset] = bit32.band(bitField, bit32.bnot(bit32.lshift(1, componentId - 1 - (32 * (offset - 1)))))
end

local function isComponentBitSet(entity, componentId)
	local offset = math.ceil((componentId * 0.03125))
	local bitField = EntityMap[entity][0][offset]

	return bit32.band(bit32.rshift(bitField, componentId - 1 - (32 * (offset - 1)))) == 1
end

function checkFilter(systemEntities, instance)
	local entityBitFields = EntityMap[instance][0]

	for filterId, bitFields in ipairs(EntityFilters) do
		if bit32.band(bitFields[1], entityBitFields[1]) == bitFields[1] and bit32.band(bitFields[2], entityBitFields[2]) == bitFields[2] then
			if not systemEntities[instance] then
				FilteredEntityAddedFuncs[filterId](instance)
				systemEntities[instance] = true
			end
		else
			if systemEntities[instance] then
				FilteredEntityRemovedFuncs[filterId](instance)
				systemEntities[instance] = nil
			end
		end
	end
end

local function filterEntity(instance)
	checkFilter(HeartbeatSystemEntities, instance)
	checkFilter(SystemEntities, instance)
end

local function addEntity(instance)
	EntityMap[instance] = { [0] = { 0, 0 } } -- fields for fast intersection tests
	CollectionService:AddTag(instance, "__WSEntity")
	return instance
end

---Adds a component to the destruction cache
-- @param entity
-- @param componentId
local function cacheComponentKilled(entity, componentId)
	KilledComponents[componentId][entity] = true
end

local function doUnloadSystem(system)
	if system.OnUnloaded then
		system.OnUnloaded()
	end

	if system._heartbeatId then
		local heartbeatLen = #HeartbeatSystems
		local entitiesLen = #HeartbeatSystemEntities

		HeartbeatSystems[heartbeatId] = HeartbeatSystems[heartbeatLen]
		HeartbeatSystems[heartbeatLen] = nil
		HeartbeatSystemEntities[heartbeatId] = HeartbeatSystemEntities[entitiesLen]
		HeartbeatSystemEntities[entitiesLen] = nil
	end

	if system._filterId then
		local filterLen = #EntityFilters

		EntityFilters[filterId] = EntityFilters[filterLen]
		EntityFilters[filterLen] = nil
	end
end

local function doReorder(componentId, parentEntitiesMap)
	if not next(parentEntitiesMap) then
		return
	end

	local componentList = ComponentMap[componentId]
	local keptComponentOffset = 1
	local numRemovedComponents = 0

	for _, component in ipairs(componentList) do
		local instance = component.Instance
		local entityStruct = EntityMap[instance]
		local componentOffset = entityStruct[componentId]

		if not parentEntitiesMap[instance] then
			if componentOffset ~= keptComponentOffset then
				-- swap
				componentList[keptComponentOffset] = componentList[componentOffset]
				entityStruct[componentId] = keptComponentOffset
				componentList[componentOffset] = nil
			end

			keptComponentOffset = keptComponentOffset + 1
		else
		   	-- kill
			ComponentRemovedFuncs[componentId](component)
			componentList[componentOffset] = nil
			entityStruct[componentId] = nil
			parentEntitiesMap[instance] = nil
			unsetComponentBitForEntity(instance, componentId)

			if not next(entityStruct) then
				-- dead
				CollectionService:RemoveTag(instance, "__WSEntity")
				EntityMap[instance] = nil
			end

			filterEntity(instance)
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
		local instance = component.Instance

		ComponentAddedFuncs[componentId](component)
		EntityMap[instance][componentId] = componentOffset
		ComponentMap[componentId][componentOffset] = component
		AddedComponents[i] = nil
		setComponentBitForEntity(instance, componentId)
		filterEntity(instance)
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
ComponentDesc._defUpdateCallback = initComponentDefs

-- Public API
--------------------------------------------------------------------------------------------------------------------------------------------------
local EntityManager = {}

---Adds a component of type componentType to instance with parameters specified by paramMap
-- If instance does not already have an associated entity, a new entity will be created
-- If instance already has componentType, the instance's componentType will be overwritten
-- This operation is cached - creation occurs on the RunService's heartbeat or between system steps
-- See ~/src/ComponentFactory for performance notes

-- @param instance
-- @param componentType
-- @param paramMap Table containing values of parameters that will be set for this component, indexed by parameter name
-- @return The new component object

function EntityManager.AddComponent(instance, componentType, paramMap)
	if not EntityMap[instance] then
		addEntity(instance)
	end

	local component = ComponentFactory(instance, componentType, paramMap)
	AddedComponents[#AddedComponents + 1] = component
	return component
end

---Gets the component of type componentType associated with instance
-- If instance is not associated with an entity or does not have componentTpye, this function returns nil
-- @param instance
-- @param componentType
-- @return The component object of type componentType associated with instance
function EntityManager.GetComponent(instance, componentType)
	local entityStruct = EntityMap[instance]

	if not entityStruct then
		return
	end

	local componentId = GetComponentIdFromType(componentType)
	local componentIndex = entityStruct[componentId]
	if componentIndex then
		return ComponentMap[componentId][componentIndex]
	end
end

---Gets the list of components of type componentType
-- If there exists no components of type componentType, this function returns an empty table
-- @param componentType
-- @return The list of component objects
function EntityManager.GetAllComponentsOfType(componentType)
	return ComponentMap[GetComponentIdFromType(componentType)]
end

function EntityManager.ComponentAdded(componentType, func)
	WSAssert(typeof(componentType) == "string", "bad argument #1: expected string")
	WSAssert(typeof(func) == "function", "bad argument #2: expected function")

	local componentId = GetComponentIdFromType(componentType)

	ComponentAddedFuncs[componentId] = func
end

function EntityManager.ComponentKilled(componentType, func)
	WSAssert(typeof(componentType) == "string", "bad argument #1: expected string")
	WSAssert(typeof(func) == "function", "bad argument #2: expected function")

	local componentId = GetComponentIdFromType(componentType)

	ComponentRemovedFuncs[componentId] = func
end

function EntityManager.FilteredEntityAdded(system, func)
	WSAssert(system.EntityFilter, "expected table .EntityFilter")

	FilteredEntityAddedFuncs[system._filterId] = func
end

function EntityManager.FilteredEntityRemoved(system, func)
	WSAssert(system.EntityFilter, "expected table .EntityFilter")

	FilteredEntityRemovedFuncs[system._filterId] = func
end

---Removes component of type componentType from the entity associated with instance
-- If instance is not associated with an entity or instance does not have componentType, this function returns without doing anything
-- This operation is cached - destruction occurs on the RunService's heartbeat or between system steps
-- @param instance
-- @param componentType
function EntityManager.KillComponent(instance, componentType)
	local entityStruct = EntityMap[instance]

	if not entityStruct then
		return
	end

	local componentId = typeof(componentType) == "number" and componentType or GetComponentIdFromType(componentType)
	local componentIndex = entityStruct[componentId]
	if componentIndex then
		cacheComponentKilled(instance, componentId)
	end
end

---Removes the entity (and by extension, all components) associated with instance
-- If instance is not associated with an entity, this function returns without doing anything
-- This operation is cached - destruction occurs on the RunService's heartbeat or between system steps
-- @param instance
function EntityManager.KillEntity(instance, supressInstanceDestruction)
	local entityStruct = EntityMap[instance]

	if not entityStruct then
		return
	end

	-- can be switched to ipairs if there are no holes in component ids
	for componentId in pairs(entityStruct) do
		-- if statement may be removed if using ipairs
		if not componentId == 0 then
			cacheComponentKilled(instance, componentId)
		end
	end

	if not supressInstanceDestruction then
		instance:Destroy()
	end
end

---Loads the system defined by module
-- If the system has a .OnLoaded() member, then it is called by this function
-- If the system has a .Heartbeat() member, then it is loaded to be ran when EntityManager.StartSystems() is called

-- @param module
-- @param pluginWrapper
function EntityManager.LoadSystem(module, pluginWrapper)
	WSAssert(typeof(module) == "Instance" and module:IsA("ModuleScript"), "bad argument #1: expected ModuleScript")

	if system.OnLoaded then
		WSAssert(typeof(system.OnLoaded) == "function", "expected function %s.OnLoaded", module.Name)

		system.OnLoaded(pluginWrapper)
	end

	if system.Heartbeat then
		WSAssert(typeof(system.Heartbeat) == "function", "expected function %s.Heartbeat", module.Name)

		local heartbeatId = #HeartbeatSystems + 1

		HeartbeatSystems[heartbeatId] = system.Heartbeat
	end

	if system.EntityFilter then
		WSAssert(typeof(system.EntityFilter) == "table" and #system.EntityFilter > 0, "expected array %s.EntityFilter", module.Name)

		local filterId = #EntityFilters + 1
		local entityFilter

		EntityFilters[filterId] = { 0, 0 }
		entityFilter = EntityFilters[filterId]
		SystemFilteredEntities[filterId] = {}
		system.FilteredEntities = SystemFilteredEntities[filterId]

		for i, componentType in pairs(system.EntityFilter) do
			WSAssert(typeof(componentType) == "string" and typeof(i) == "number", "EntityFilter should be a string-valued array")
		end

		for i, componentType in ipairs(system.EntityFilter) do
			local componentId = GetComponentIdFromType(componentType)
			local offset = math.ceil(componentId * 0.03125)
			local bitField = entityFilter[offset]

			entityFilter[offset] = bit32.bor(bitField, bit32.lshift(1, componentId - 1 - (32 * (offset - 1))))
		end
	end
end
---Unloads the system defined by module
-- If the system has a .OnUnloaded member, then it is called by this function
-- System is unloaded by EntityManager.StartSystem()'s loop on the next RunServive.Heartbeat step
function EntityManager.UnloadSystem(module)
	WSAssert(typeof(module) == "Instance" and module:IsA("ModuleScript"), "bad argument #1: expected ModuleScript")

	local system = require(module)

	WSAssert(not system.Locked, "system is locked")

	if system.OnUnloaded then
		WSAssert(typeof(system.OnUnloaded) == "function", "expected function %s.OnUnloaded", module.Name)
	end

	SystemsToUnload[#SystemsToUnload + 1] = system
end

---Starts execution of continuously run systems and the component lifetime loop
-- If no system has a .Step() member, then only the component lifetime loop will be executed
-- This function blocks execution in the calling thread
function EntityManager.StartSystems()

	WSAssert(not SystemsRunning, "Systems already started")

	SystemsRunning = true

	local hasHeartbeat = #HeartbeatSystems > 0 and true or nil
	local lastFrameTime = RunService.Heartbeat:Wait()

	while SystemsRunning do
		for i, system in ipairs(SystemsToUnload) do
			doUnloadSystem(system.OnUnloaded, system._systemId)
			SystemsToUnload[i] = nil
		end

		if not hasHeartbeat then
			stepComponentLifetime()
		end

		for id, system in ipairs(HeartbeatSystems) do
		   	stepComponentLifetime()
			system(lastFrameTime, HeartbeatSystemEntities[id])
		end

		lastFrameTime = RunService.Heartbeat:Wait()
	end
end

function EntityManager.StopSystems()
	SystemsRunning = false
end

function EntityManager.GetComponentDesc()
	return ComponentDesc
end

function EntityManager.Destroy()
	-- maybe overkill
	SystemsRunning = false
end

function EntityManager.Init()
end

return EntityManager
