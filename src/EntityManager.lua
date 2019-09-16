-- EntityManager.lua
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ComponentDesc = require(script.Parent.ComponentDesc)
local ComponentFactory = require(script.Parent.ComponentFactory)
local Constants = require(script.Parent.Constants)
local EntityReplicator = (Constants.IS_SERVER or Constants._IS_CLIENT) and require(script.Parent.EntityReplicator)
local WSAssert = require(script.Parent.WSAssert)

-- Internal
--------------------------------------------------------------------------------------------------------------------------------------------------
local EntityMap = {}
local ComponentMap = {}
local KilledComponents = {}
local AddedComponents = {}
local HeartbeatSystems = {}
local FilterIdsBySystem = {}
local HeartbeatIdsBySystem = {}
local EntityFilters = {}
local ComponentRemovedFuncs = {}
local ComponentAddedFuncs = {}
local FilteredEntityAddedFuncs = {}
local FilteredEntityRemovedFuncs = {}
local SystemFilteredEntities = {}
local SystemsToUnload = {}
local SystemMap = {}

local SystemsRunning = false

local GetComponentIdFromType = ComponentDesc.GetComponentIdFromType
local ReplicatorStep = EntityReplicator and EntityReplicator.Step
local AddComponent

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

local function filterEntity(instance)
	local entityBitFields = EntityMap[instance][0]
	local addedFunc
	local removedFunc
	local systemEntities

	for filterId, bitFields in ipairs(EntityFilters) do
		addedFunc = FilteredEntityAddedFuncs[filterId]
		removedFunc = FilteredEntityRemovedFuncs[filterId]
		systemEntities = SystemFilteredEntities[filterId]

		if bit32.band(bitFields[1], entityBitFields[1]) == bitFields[1] and bit32.band(bitFields[2], entityBitFields[2]) == bitFields[2] then
			if not systemEntities[instance] then
				systemEntities[instance] = true

				if addedFunc then
					addedFunc(instance)
				end
			end
		else
			if systemEntities[instance] then
				systemEntities[instance] = nil

				if removedFunc then
					removedFunc(instance)
				end
			end
		end
	end
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
	local filterId = FilterIdsBySystem[system]
	local heartbeatId = HeartbeatIdsBySystem[system]
	local len

	if system.OnUnloaded then
		system.OnUnloaded()
	end

	if filterId then
		len = #EntityFilters

		EntityFilters[filterId] = EntityFilters[len]
		EntityFilters[len] = nil

		SystemFilteredEntities[filterId] = SystemFilteredEntities[len]
		SystemFilteredEntities[len] = nil

		FilteredEntityAddedFuncs[filterId] = nil
		FilteredEntityRemovedFuncs[filterId] = nil

		FilterIdsBySystem[system] = nil

		for sys, id in pairs(FilterIdsBySystem) do
			if id == len then
				FilterIdsBySystem[sys] = filterId
				break
			end
		end
	end

	if heartbeatId then
		len = #HeartbeatSystems

		HeartbeatSystems[heartbeatId] = HeartbeatSystems[len]
		HeartbeatSystems[len] = nil

		HeartbeatIdsBySystem[system] = nil

		for sys, id in pairs(HeartbeatIdsBySystem) do
			if id == len then
				HeartbeatIdsBySystem[sys] = heartbeatId
				break
			end
		end
	end

	SystemMap[system] = nil
end

local function doReorder(componentId, parentEntitiesMap)
	if not next(parentEntitiesMap) then
		return
	end

	local componentList = ComponentMap[componentId]
	local keptComponentOffset = 1
	local instance
	local entityStruct

	for componentOffset, component in ipairs(componentList) do
		instance = component.Instance
		entityStruct = EntityMap[instance]

		if not parentEntitiesMap[instance] then
			if componentOffset ~= keptComponentOffset then
				-- swap
				componentList[keptComponentOffset] = component
				entityStruct[componentId] = keptComponentOffset
				componentList[componentOffset] = nil
			end

			keptComponentOffset = keptComponentOffset + 1
		else
			local removedFunc = ComponentRemovedFuncs[componentId]
			-- kill
			if removedFunc then
				removedFunc(component)
			end

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
	local componentId
	local componentOffset
	local instance
	local addedFunc

	for compId, parentEntitiesMap in pairs(KilledComponents) do
		doReorder(compId, parentEntitiesMap)
	end

	for i, component in ipairs(AddedComponents) do
		componentId = component._componentId
		addedFunc = ComponentAddedFuncs[componentId]
		componentOffset = #ComponentMap[componentId] + 1
		instance = component.Instance

		if addedFunc then
			addedFunc(component)
		end

		EntityMap[instance][componentId] = componentOffset
		ComponentMap[componentId][componentOffset] = component
		AddedComponents[i] = nil
		setComponentBitForEntity(instance, componentId)
		filterEntity(instance)
	end
end

-- Initialization
local function initComponentDefs()
	local componentId

	for _, componentDefinition in pairs(ComponentDesc.ComponentDefinitions) do
		componentId = componentDefinition[1]
		ComponentMap[componentId] = not ComponentMap[componentId] and {}
		KilledComponents[componentId] = not KilledComponents[componentId] and {}
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
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(typeof(componentType) == "string", "bad argument #2 (expected string)")
	WSAssert(paramMap ~= nil and typeof(paramMap) == "table"or true, "bad argument #3 (expected table)")

	if not EntityMap[instance] then
		addEntity(instance)
	end

	local component = ComponentFactory(instance, componentType, paramMap)

	AddedComponents[#AddedComponents + 1] = component

	return component
end

AddComponent = EntityManager.AddComponent

---Gets the component of type componentType associated with instance
-- If instance is not associated with an entity or does not have componentType, this function returns nil
-- @param instance
-- @param componentType
-- @return The component object of type componentType associated with instance

function EntityManager.GetComponent(instance, componentType)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(typeof(componentType) == "string", "bad argument #2 (expected string)")

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
-- If there exist no components of type componentType, this function returns an empty table
-- @param componentType
-- @return The list of component objects

function EntityManager.GetAllComponentsOfType(componentType)
	WSAssert(typeof(componentType) == "string", "bad argument #1 (expected string)")

	return ComponentMap[GetComponentIdFromType(componentType)]
end

---Hooks a function func to be called whenever just before of type componentType are added to an entity
-- The component object is passed as a parameter to func
-- @param componentType
-- @Param func

function EntityManager.ComponentAdded(componentType, func)
	WSAssert(typeof(componentType) == "string", "bad argument #1 (expected string)")
	WSAssert(typeof(func) == "function", "bad argument #2 (expected function)")

	local componentId = GetComponentIdFromType(componentType)

	ComponentAddedFuncs[componentId] = func
end

---Hooks a function func to be called just before components of type componentType are removed from an entity
-- The component object is passed as a parameter to func
-- @param componentType
-- @param func

function EntityManager.ComponentKilled(componentType, func)
	WSAssert(typeof(componentType) == "string", "bad argument #1 (expected string)")
	WSAssert(typeof(func) == "function", "bad argument #2 (expected function)")

	local componentId = GetComponentIdFromType(componentType)

	ComponentRemovedFuncs[componentId] = func
end

---Hooks a function func to be called just after an entity matches the .EntityFilter table in system
-- system must have a .EntityFilter field
-- The instance associated with the filtered entity is passed as a parameter to func
-- @param system
-- @param func

function EntityManager.FilteredEntityAdded(system, func)
	WSAssert(system.EntityFilter, "expected table .EntityFilter")
	WSAssert(typeof(func) == "function", "bad argument #2 (expected function)")

	FilteredEntityAddedFuncs[FilterIdsBySystem[system]] = func
end

---Hooks a function func to be called just after a filtered entity fails to match the .EntityFilter table in system
-- system must have a .EntityFilter field
-- The instance associated with the filtered entity is passed as a parameter to func
-- @param system
-- @param func

function EntityManager.FilteredEntityRemoved(system, func)
	WSAssert(system.EntityFilter, "expected table .EntityFilter")
	WSAssert(typeof(func) == "function", "bad argument #2 (expected function)")

	FilteredEntityRemovedFuncs[FilterIdsBySystem[system]] = func
end

---Removes component of type componentType from the entity associated with instance
-- If instance is not associated with an entity or instance does not have componentType, this function returns without doing anything
-- This operation is cached - destruction occurs on the RunService's heartbeat or between system steps
-- @param instance
-- @param componentType

function EntityManager.KillComponent(instance, componentType)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(typeof(componentType) == "string", "bad argument #2 (expected string)")

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
-- supressInstanceDestruction is a boolean which determines whether to destroy the instance, along with its associated entity
-- This operation is cached - destruction occurs on the RunService's heartbeat or between system steps
-- @param instance
-- @param supressInstanceDestruction

function EntityManager.KillEntity(instance, supressInstanceDestruction)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(supressInstanceDestruction and typeof(supressInstanceDestruction) == "boolean", "bad argument #2 (expected boolean)")

	local entityStruct = EntityMap[instance]

	if not entityStruct then
		return
	end

	for componentId in pairs(entityStruct) do
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
-- @param _pluginWrapper

function EntityManager.LoadSystem(module, _pluginWrapper)
	WSAssert(typeof(module) == "Instance" and module:IsA("ModuleScript"), "bad argument #1 (expected ModuleScript)")

	local system = require(module)

	if system.OnLoaded then
		WSAssert(typeof(system.OnLoaded) == "function", "expected function %s.OnLoaded", module.Name)

		system.OnLoaded(_pluginWrapper)
	end

	if system.Heartbeat then
		WSAssert(typeof(system.Heartbeat) == "function", "expected function %s.Heartbeat", module.Name)

		local heartbeatId = #HeartbeatSystems + 1

		HeartbeatSystems[heartbeatId] = system.Heartbeat
		HeartbeatIdsBySystem[system] = heartbeatId
	end

	if system.EntityFilter then
		WSAssert(typeof(system.EntityFilter) == "table" and #system.EntityFilter > 0, "expected array %s.EntityFilter", module.Name)

		local filterId = #EntityFilters + 1
		local filter = { 0, 0 }

		EntityFilters[filterId] = filter
		SystemFilteredEntities[filterId] = {}
		system.FilteredEntities = SystemFilteredEntities[filterId]
		FilterIdsBySystem[system] = filterId

		for i, componentType in pairs(system.EntityFilter) do
			WSAssert(typeof(componentType) == "string" and typeof(i) == "number", "EntityFilter should be a string-valued array")
		end

		for _, componentType in ipairs(system.EntityFilter) do
			local componentId = GetComponentIdFromType(componentType)
			local offset = math.ceil(componentId * 0.03125)
			local bitField = filter[offset]

			filter[offset] = bit32.bor(bitField, bit32.lshift(1, componentId - 1 - (32 * (offset - 1))))
		end
	end

	SystemMap[system] = true
end

---Unloads the system defined by module
-- If the system has a .OnUnloaded member, then it is called by this function
-- System is unloaded by EntityManager.StartSystem()'s loop on the next RunServive.Heartbeat step
-- @param module

function EntityManager.UnloadSystem(module)
	WSAssert(typeof(module) == "Instance" and module:IsA("ModuleScript"), "bad argument #1 (expected ModuleScript)")

	local system = require(module)

	WSAssert(not system.Locked, "System is locked")

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

	if EntityReplicator then
		EntityReplicator.Init(EntityManager, EntityMap, ComponentMap)
	end

	SystemsRunning = true

	local hasHeartbeat = #HeartbeatSystems > 0 and true or nil
	local lastFrameTime = RunService.Heartbeat:Wait()

	while SystemsRunning do
		for i, system in ipairs(SystemsToUnload) do
			doUnloadSystem(system)
			SystemsToUnload[i] = nil
		end

		if not hasHeartbeat then
			stepComponentLifetime()
		end

		for _, systemStep in ipairs(HeartbeatSystems) do
			stepComponentLifetime()
			systemStep(lastFrameTime)
		end

		if ReplicatorStep then
			ReplicatorStep(lastFrameTime)
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
	for system in pairs(SystemMap) do
		if system.OnUnloaded then
			system.OnUnloaded()
		end
	end

	-- wait two to ensure we dont land on the same frame
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()

	SystemsRunning = false
end

function EntityManager.Init()
	local entities = CollectionService:GetTagged("__WSEntities")
	local data

	for _, instance in pairs(entities) do
		if not instance:FindFirstChild("__WSEntity") then
			warn(("Tagged entity %s has no associated data (missing __WSEntity module)"):format(instance:GetFullName()))
		else
			data = require(instance.__WSEntity)

			for componentType, paramsInfo in ipairs(data) do
				local numParams = #paramsInfo
				local componentStruct = {
					true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
					_componentId = 0, Instance = 0
				}

				for paramId, paramValue in ipairs(paramsInfo) do
					componentStruct[paramId] = paramValue
				end

				for i = 16, numParams < 16 and numParams + 1 or numParams, -1 do
					componentStruct[i] = nil
				end

				AddComponent(instance, componentType, componentStruct)
			end

			instance.__WSEntity:Destroy()
		end
	end
end

return EntityManager

