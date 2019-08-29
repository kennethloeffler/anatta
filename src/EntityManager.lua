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
local EntityMap = {}
local ComponentMap = {}
local KilledComponents = {}
local AddedComponents = {}
local ComponentAddedEvents = {}
local ComponentRemovedEvents = {}
local SystemsRunning = false
local EntityFilters = {}
local SystemEntities = {}
local Systems = {}
local SystemsToUnload = {}

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

local function filterEntity(instance)
	local entityBitFields = EntityMap[instance][0]
	local firstField = 0
	local secondField = 0

	for systemId, bitFields in ipairs(EntityFilters) do
		if bit32.band(firstField, entityBitFields[1]) == firstField and bit32.band(secondField, entityBitFields[2]) == secondField then
			SystemEntities[systemId][instance] = true
		else
			SystemEntities[systemId][instance] = nil
		end
	end
end

local function addEntity(instance)
	EntityMap[instance] = { [0] = { 0, 0 } } -- bit fields for fast intersection tests
	CollectionService:AddTag(instance, "__WSEntity")
	return instance
end

---Adds a component to the destruction cache
-- @param entity
-- @param componentId
local function cacheComponentKilled(entity, componentId)
	KilledComponents[componentId][entity] = true
end

local function doUnloadSystem(onUnloadedCallback, systemId)
	if onUnloadedCallback then
		onUnloadedCallback()
	end

	if systemId then
		local heartbeatLen = #Systems
		local entitiesLen = #SystemEntities
		local filtersLen = #EntityFilters

		Systems[systemId] = Systems[heartbeatLen]
		Systems[heartbeatLen] = nil
		SystemEntities[systemId] = SystemEntities[entitiesLen]
		SystemEntities[entitiesLen] = nil
		EntityFilters[systemId] = EntityFilters[filtersLen]
		EntityFilters[systemId] = nil
	end
end

local function doReorder(componentId, parentEntitiesMap)

	if not next(parentEntitiesMap) then
		return
	end

	local componentList = ComponentMap[componentId]
	local keptComponentOffset = 1
	for _, component in ipairs(componentList) do
		local instance = component.Instance
		local componentOffset = EntityMap[instance][componentId]
		if not parentEntitiesMap[instance] then
			if componentOffset ~= keptComponentOffset then
				-- swap
				componentList[keptComponentOffset] = componentList[componentOffset]
				EntityMap[instance][componentId] = keptComponentOffset
				componentList[componentOffset] = nil
			end
			keptComponentOffset = keptComponentOffset + 1
		else
		   	-- kill
			componentList[componentOffset] = nil
			EntityMap[instance][componentId] = nil
			parentEntitiesMap[instance] = nil
			unsetComponentBitForEntity(instance, componentId)
			ComponentRemovedEvents[componentId]:Fire(instance)
			filterEntity(instance)
			if not next(EntityMap[instance]) then
				-- dead
				CollectionService:RemoveTag(instance, "__WSEntity")
				EntityMap[instance] = nil
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
		local instance = component.Instance
		EntityMap[instance][componentId] = componentOffset
		ComponentMap[componentId][componentOffset] = component
		AddedComponents[i] = nil
		setComponentBitForEntity(instance, componentId)
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

	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
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

function EntityManager.FilteredEntityAdded(entityFilter)
	local bindable = Instance.new("BindableEvent")
	local bitFields = { 0, 0 }

	for i, componentType in ipairs(entityFilter) do
		WSAssert(typeof(i) == "number", typeof(componentType) == "string", "argument should be a string-valued array")

		local offset = math.ceil(componentId * 0.03125) -- componentId / 32
		local componentId = ComponentDesc.GetComponentIdFromType(componentType)

		bitFields[offset] = bReplace(bitField, value, componentId - 1 - (32 * (offset - 1)))

		ComponentAddedEvents[componentId]:Connect(function(instance)
			local entityBitFields = EntityMap[instance][0]
			local firstField = bitFields[1]
			local secondField = bitFields[2]

			if bit32.band(firstField, entityBitFields[1]) == firstField and bit32.band(secondField, entityBitFields[2]) then
				bindable.Event:Fire(instance)
			end
		end)
	end
	return bindable.Event
end

function EntityManager.FilteredEntityRemoved(entityFilter)
	local bindable = Instance.new("BindableEvent")
	local bitFields = { 0, 0 }

	for i, componentType in ipairs(entityFilter) do
		WSAssert(typeof(i) == "number", typeof(componentType) == "string", "argument should be a string-valued array")

		local offset = math.ceil(componentId * 0.03125) -- componentId / 32
		local componentId = ComponentDesc.GetComponentIdFromType(componentType)

		bitFields[offset] = bReplace(bitField, value, componentId - 1 - (32 * (offset - 1)))

		ComponentRemovedEvents[componentId]:Connect(function(instance)
			local entityBitFields = EntityMap[instance][0]
			local firstField = bitFields[1]
			local secondField = bitFields[2]

			if not (bit32.band(firstField, entityBitFields[1]) == firstField and bit32.band(secondField, entityBitFields[2])) then
				bindable.Event:Fire(instance)
			end
		end)
	end

	return bindable.Event
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

	local componentId = typeof(componentType) == "number" and componentType or ComponentDesc.GetComponentIdFromType(componentType)
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

	local system = require(module)

	if system.OnLoaded then
		WSAssert(typeof(system.OnLoaded) == "function", "expected function %s.OnLoaded", module.Name)

		system.OnLoaded(pluginWrapper)
	end

	if system.Heartbeat then
		WSAssert(typeof(system.Heartbeat) == "function", "expected function %s.Heartbeat", module.Name)

		local systemId = #Systems + 1
		Systems[systemId] = system
		system._systemId = systemId

		if system.EntityFilter then
			WSAssert(typeof(system.EntityFilter) == "table" and #system.EntityFilter > 0, "expected array %s.EntityFilter", module.Name)

			for i, componentType in pairs(system.EntityFilter) do
				WSAssert(typeof(componentType) == "string" and typeof(i) == "number", "EntityFilter should be a string-valued array")
			end

			EntityFilters[systemId] = { 0, 0 }
			SystemEntities[systemId] = {}

			for i, componentType in ipairs(system.EntityFilter) do
				local componentId = ComponentDesc.GetComponentIdFromType(componentType)
				local offset = math.ceil(componentId * 0.03125)
				local bitField = EntityFilters[systemId][offset]

				EntityFilters[systemId][offset] = bit32.bor(bitField, bit32.lshift(1, componentId - 1 - (32 * (offset - 1))))
			end
		end
	end
end
---Unloads the system defined by module
-- If the system has a .OnUnloaded member, then it is called by this function
-- System is unloaded by EntityManager.StartSystem()'s loop on the next RunServive.Heartbeat step
function EntityManager.UnloadSystem(module)
	WSAssert(typeof(module) == "Instance" and module:IsA("ModuleScript"), "bad argument #1: expected ModuleScript")

	local system = require(module)
	local systemId = system._systemId

	WSAssert(not system.Locked, "system is locked")

	if system.OnUnloaded then
		WSAssert(typeof(system.OnUnloaded) == "function", "expected function %s.OnUnloaded", module.Name)
	end

	SystemsToUnload

---Starts execution of continuously run systems and component lifetime loop
-- If no system has a .Step() member, then only the component lifetime loop will be executed
-- This is a blocking function
function EntityManager.StartSystems()

	if SystemsRunning then
		warn("Systems already running")
		return
	end

	SystemsRunning = true

	local hasContinuouslyRunningSystems = #Systems > 0 and true or nil
	local lastFrameTime = RunService.Heartbeat:Wait()

	while SystemsRunning do
		if not hasContinuouslyRunningSystems then
			stepComponentLifetime()
		end

		for systemId, system in ipairs(Systems) do
		   	stepComponentLifetime()
			system(lastFrameTime, SystemEntities[systemId])
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
	for componentId in pairs(ComponentRemovedEvents) do
		ComponentRemovedEvents[componentId]:Destroy()
	end
	for componentId in pairs(ComponentAddedEvents) do
		ComponentAddedEvents[componentId]:Destroy()
	end
end

return EntityManager
