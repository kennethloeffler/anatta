-- EntityManager.lua

-- Copyright 2019 Kenneth Loeffler

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

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
local tagName = script:IsDescendantOf(game:GetService("ReplicatedStorage")) and "__WSEntity" or "__WSPluginEntity"

local GetComponentIdFromType = ComponentDesc.GetComponentIdFromType
local ReplicatorStep = EntityReplicator and EntityReplicator.Step
local AddComponent

local function setComponentBitForEntity(entity, componentId)
	if componentId > 64 then
		return
	end

	local offset = math.ceil(componentId * 0.03125) -- componentId / 32
	local bitField = EntityMap[entity][1][offset]

	EntityMap[entity][1][offset] = bit32.bor(bitField, bit32.lshift(1, componentId - 1 - (32 * (offset - 1))))
end

local function unsetComponentBitForEntity(entity, componentId)
	if componentId > 64 then
		return
	end

	local offset = math.ceil(componentId * 0.03125)
	local bitField = EntityMap[entity][1][offset]

	EntityMap[entity][1][offset] = bit32.band(bitField, bit32.bnot(bit32.lshift(1, componentId - 1 - (32 * (offset - 1)))))
end

local function filterEntity(instance)
	local entityBitFields = EntityMap[instance][1]
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
	EntityMap[instance] = { { 0, 0 } } -- fields for fast intersection tests
	CollectionService:AddTag(instance, tagName)

	return EntityMap[instance]
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

local function doReorder(componentId, componentList)
	local keptComponentOffset = 1
	local numKilledComponents = 0
	local masterComponentList = ComponentMap[componentId]
	local instance
	local entityStruct
	local doKill
	local cIndex

	for componentOffset, component in ipairs(masterComponentList) do
		instance = component.Instance
		entityStruct = EntityMap[instance]
		doKill = componentList[component]
		cIndex = entityStruct[componentId + 1]

		if doKill == nil then
			if componentOffset ~= keptComponentOffset then
				-- swap
				masterComponentList[keptComponentOffset] = component
				masterComponentList[componentOffset] = nil
				entityStruct[componentId + 1] = keptComponentOffset
			end

			keptComponentOffset = keptComponentOffset + 1
		else
			local removedFunc = ComponentRemovedFuncs[componentId]
			-- kill
			if removedFunc then
				removedFunc(component)
			end

			numKilledComponents = numKilledComponents + 1
			masterComponentList[componentOffset] = nil
			componentList[component] = nil
			unsetComponentBitForEntity(instance, componentId)

			if typeof(cIndex) == "number" then
				entityStruct[componentId + 1] = nil
			else	-- list typed
				local l = #cIndex

				for i, index in ipairs(cIndex) do
					if index == componentOffset then
						cIndex[i] = cIndex[l]
						cIndex[l] = nil
						break
					end
				end

				if not cIndex[1] then
					entityStruct[componentId + 1] = nil
				end
			end

			if not next(entityStruct) and not doKill then
				-- dead
				CollectionService:RemoveTag(instance, tagName)
				EntityMap[instance] = nil
			end

			if componentId <= 64 then
				filterEntity(instance)
			end
		end
	end

	masterComponentList._length = masterComponentList._length - numKilledComponents
end

---Iterates through the component destruction cache and mutates entity-component maps accordingly
-- Called before each system step
local function stepComponentLifetime()
	for compId, componentList in ipairs(KilledComponents) do
		if next(componentList) then
			doReorder(compId, componentList)
		end
	end
end

-- Initialization
local function initComponentDefs()
	for _, componentId in pairs(ComponentDesc.GetAllComponents()) do
		ComponentMap[componentId] = { _length = 0 }
		KilledComponents[componentId] = {}
	end
end

initComponentDefs()
ComponentDesc._defUpdateCallback = initComponentDefs

-- Public API
--------------------------------------------------------------------------------------------------------------------------------------------------
local EntityManager = {}

---Adds a component of type componentType to instance with parameters specified by paramMap
-- If instance does not already have an associated entity, a new entity will be created
-- If instance already has componentType and componentType is not list-typed, the instance's componentType will be overwritten
-- See ~/src/ComponentFactory for performance notes
-- @param instance
-- @param componentType
-- @param paramMap Table containing values of parameters that will be set for this component, indexed by parameter name
-- @return The new component object

function EntityManager.AddComponent(instance, componentType, paramMap)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(typeof(componentType) == "string", "bad argument #2 (expected string)")
	WSAssert(paramMap == nil or typeof(paramMap) == "table", "bad argument #3 (expected table)")

	local entityStruct = EntityMap[instance] or addEntity(instance)
	local componentId = GetComponentIdFromType(componentType)
	local component = ComponentFactory(instance, componentId, paramMap)
	local addedFunc = ComponentAddedFuncs[componentId]
	local componentList = ComponentMap[componentId]
	local componentOffset = componentList._length + 1
	local offsetIndex = entityStruct[componentId + 1]

	if not component._list then
		entityStruct[componentId + 1] = componentOffset
	else
		if offsetIndex then
			offsetIndex[#offsetIndex + 1] = componentOffset
		else
			entityStruct[componentId + 1] = { componentOffset }
		end
	end

	componentList._length = componentOffset
	componentList[componentOffset] = component
	setComponentBitForEntity(instance, componentId)

	if addedFunc then
		addedFunc(component)
	end

	if componentId <= 64 then
		filterEntity(instance)
	end

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
	local componentIndex = entityStruct[componentId + 1]

	if componentIndex then
		return ComponentMap[componentId][componentIndex]
	end
end

function EntityManager.GetListTypedComponent(instance, componentType)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(typeof(componentType) == "string", "bad argument #2 (expected string)")

	local entityStruct = EntityMap[instance]

	if not entityStruct then
		return
	end

	local componentId = GetComponentIdFromType(componentType)
	local componentIndex = entityStruct[componentId + 1]

	local struct = {}

	if not componentIndex then
		return struct
	end

	WSAssert(typeof(componentIndex) == "table", "%s is not a list-typed component", componentType)

	for _, offset in ipairs(componentIndex) do
		struct[#struct + 1] = ComponentMap[componentId][offset]
	end

	return struct
end

function EntityManager.GetComponents(instance)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")

	local entityStruct = EntityMap[instance]

	if not entityStruct then
		return
	end

	local struct = {}

	for componentId, cOffset in pairs(entityStruct) do
		if componentId > 1 then
			if typeof(cOffset) == "number" then
				struct[#struct + 1] = ComponentMap[componentId - 1][cOffset]
			elseif typeof(cOffset) == "table" then
				for _, offset in ipairs(cOffset) do
					struct[#struct + 1] = ComponentMap[componentId - 1][offset]
				end
			end
		end
	end

	return struct
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

	ComponentAddedFuncs[GetComponentIdFromType(componentType)] = func
end

---Hooks a function func to be called just before components of type componentType are removed from an entity
-- The component object is passed as a parameter to func
-- @param componentType
-- @param func

function EntityManager.ComponentKilled(componentType, func)
	WSAssert(typeof(componentType) == "string", "bad argument #1 (expected string)")
	WSAssert(typeof(func) == "function", "bad argument #2 (expected function)")

	ComponentRemovedFuncs[GetComponentIdFromType(componentType)] = func
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

function EntityManager.KillComponent(component, supressKillEntity)
	local componentId = component._componentId

	WSAssert(typeof(component) == "table" and component._componentId, "bad argument #1 (expected component)")

	KilledComponents[componentId][component] = supressKillEntity ~= nil and supressKillEntity or false
end

---Removes the entity (and by extension, all components) associated with instance
-- If instance is not associated with an entity, this function returns without doing anything
-- supressInstanceDestruction is a boolean which determines whether to destroy the instance, along with its associated entity
-- This operation is cached - destruction occurs on the RunService's heartbeat or between system steps
-- @param instance
-- @param supressInstanceDestruction

function EntityManager.KillEntity(instance, supressInstanceDestruction)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(supressInstanceDestruction == nil or typeof(supressInstanceDestruction) == "boolean", "bad argument #2 (expected boolean)")

	local entityStruct = EntityMap[instance]

	if not supressInstanceDestruction then
		instance:Destroy()
	end

	if not entityStruct then
		return
	end

	for componentId, offset in pairs(entityStruct) do
		if not componentId == 1 then
			if typeof(offset) == "table" then
				for _, index in ipairs(offset) do
					KilledComponents[componentId][ComponentMap[componentId][index]] = false
				end
			else
				KilledComponents[componentId][ComponentMap[componentId][offset]] = false
			end
		end
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
	local entities = CollectionService:GetTagged(tagName)
	local data

	for _, instance in pairs(entities) do
		if not instance:FindFirstChild("__WSEntity") then
			CollectionService:RemoveTag(instance, tagName)

			warn(("Tagged entity %s has no associated data (missing __WSEntity module)"):format(instance:GetFullName()))
		else
			data = require(instance.__WSEntity)

			for componentIdStr, paramsInfo in pairs(data) do
				local numParams = #paramsInfo
				local componentId = ComponentDesc.GetComponentIdFromEtherealId(componentIdStr) or tonumber(componentIdStr)
				local componentType = ComponentDesc.GetComponentTypeFromId(componentId)
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

			if not Constants.IS_STUDIO then
				instance.__WSEntity:Destroy()
			end
		end
	end
end

return EntityManager
