-- ComponentDesc.lua

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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(script.Parent.Constants)
local WSAssert = require(script.Parent.WSAssert)

local ComponentDefinitions = script:GetAttribute("__WSComponentDefinitions")

local ComponentIdsByType = {}
local ComponentTypesById = {}
local ComponentParamIds = {}
local ComponentIdsByEtherealId = {}
local EtherealIdsByComponentId = {}
local Defaults = {}
local NumComponentParams = {}
local ListTyped = {}

local NOT_PLUGIN = script:IsDescendantOf(ReplicatedStorage)

local ComponentDesc = {
	_defUpdateCallback = nil
}

local function popParams(componentDefinition, componentId)
	for paramId, paramDef in ipairs(componentDefinition) do
		if paramId > 1 then
			WSAssert(typeof(paramDef) == "table", "expected table")

			if paramDef.DefaultValue == "__InstanceReferent" then
				paramDef.DefaultValue = newproxy(false)
			end

			ComponentParamIds[componentId][paramDef.ParamName] = paramId - 1
			Defaults[componentId][paramDef.ParamName] = paramDef.DefaultValue
			NumComponentParams[componentId] = NumComponentParams[componentId] + 1
		end
	end
end

local function initComponentPop(componentType, componentId, isListType)
	ComponentIdsByType[componentType] = componentId
	ComponentTypesById[componentId] = componentType
	ListTyped[componentId] = isListType
	ComponentParamIds[componentId] = {}
	Defaults[componentId] = {}
	NumComponentParams[componentId] = 0
end

local function popComponent(componentIdStr, componentDefinition, maxComponentId)
	WSAssert(typeof(componentIdStr) == "string", "expected string")
	WSAssert(typeof(componentDefinition) == "table", "expected table")

	local componentType = componentDefinition[1].ComponentType
	local componentId = tonumber(componentIdStr)
	local isListType = componentDefinition[1].ListType or false

	if componentId then
		initComponentPop(componentType, componentId, isListType)
		popParams(componentDefinition, componentId)

		return componentId > maxComponentId and componentId or maxComponentId
	else
		componentId = maxComponentId + 1

		initComponentPop(componentType, componentId, isListType)
		popParams(componentDefinition, componentId)

		if Constants.IS_STUDIO then
			ComponentIdsByEtherealId[componentIdStr] = true
		end

		EtherealIdsByComponentId[componentId] = Constants.IS_STUDIO and componentIdStr

		return componentId
	end
end

local function populateDefs(definitionTable)
	local maxComponentId = 0

	for componentIdStr, componentDefinition in pairs(definitionTable) do
		maxComponentId = popComponent(componentIdStr, componentDefinition, maxComponentId)
	end
end

if Constants.IS_STUDIO and NOT_PLUGIN then
	coroutine.wrap(function()
		script:GetAttributeChangedSignal("__WSComponentDefinitions"):Connect(function()
			local componentDefinitions = script:GetAttribute("__WSComponentDefinitions") or {}

			populateDefs(componentDefinitions)

			if ComponentDesc._defUpdateCallback then
				ComponentDesc._defUpdateCallback()
			end
		end)
	end)()
end

if ComponentDefinitions then
	populateDefs(ComponentDefinitions)
end

function ComponentDesc.GetNumParams(componentId)
	return NumComponentParams[componentId]
end

function ComponentDesc.GetNumParamsAll()
	return NumComponentParams
end

function ComponentDesc.GetDefaults(componentId)
	return Defaults[componentId]
end

function ComponentDesc.GetListTyped(componentId)
	return ListTyped[componentId]
end

function ComponentDesc.GetParamDefault(componentId, paramName)
	return Defaults[componentId][paramName]
end

function ComponentDesc.GetParamIdFromName(componentId, paramName)
	return ComponentParamIds[componentId][paramName] or error(paramName .. " is not a valid parameter name", 3)
end

function ComponentDesc.GetParamNameFromId(componentId, paramId)
	for paramName, paramIdx in pairs(ComponentParamIds[componentId]) do
		if paramIdx == paramId then
			return paramName
		end
	end
end

function ComponentDesc.GetComponentIdFromType(componentType)
	return ComponentIdsByType[componentType] or error(componentType .. " is not a valid ComponentType", 3)
end

function ComponentDesc.GetComponentTypeFromId(componentId)
	return ComponentTypesById[componentId] or error(componentId .. " is not a valid component id", 3)
end

function ComponentDesc.GetAllComponents()
	return ComponentIdsByType
end

function ComponentDesc.GetComponentIdFromEtherealId(etherealId)
	return ComponentIdsByEtherealId[etherealId]
end

function ComponentDesc.GetEtherealIdFromComponentId(componentId)
	return EtherealIdsByComponentId[componentId]
end

function ComponentDesc.GetEthereal()
	return ComponentIdsByEtherealId
end

return ComponentDesc
