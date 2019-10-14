local Constants = require(script.Parent.Constants)
local WSAssert = require(script.Parent.WSAssert)

local ComponentIdsByType
local ComponentTypesById
local ComponentParamIds
local ComponentIdsByEtherealId
local EtherealIdsByComponentId
local Defaults
local NumComponentParams
local ListTyped

local ComponentDesc = {
	_defUpdateCallback = nil
}

local function popParams(componentDefinition, componentId)
	for paramId, paramDef in ipairs(componentDefinition) do
		if paramId > 1 then
			WSAssert(typeof(paramDef) == "table", "expected table")

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
	local isListType = componentDefinition[1].ListType

	if componentId then
		initComponentPop(componentType, componentId, isListType)
		popParams(componentDefinition, componentId)

		return componentId > maxComponentId and componentId or maxComponentId
	else
		componentId = maxComponentId + 1

		initComponentPop(componentType, componentId, isListType)
		popParams(componentDefinition, componentId)

		if Constants.IS_STUDIO then
			ComponentIdsByEtherealId[componentIdStr] = componentId
		end

		EtherealIdsByComponentId[componentId] = Constants.IS_STUDIO and componentIdStr or true

		return componentId
	end
end

local function populateDefs(definitionTable)
	local maxComponentId = 0

	ComponentIdsByType = {}
	ComponentTypesById = {}
	ComponentParamIds = {}
	Defaults = {}
	NumComponentParams = {}
	ListTyped = {}
	ComponentIdsByEtherealId = Constants.IS_STUDIO and {}
	EtherealIdsByComponentId = {}

	for componentIdStr, componentDefinition in pairs(definitionTable) do
		maxComponentId = popComponent(componentIdStr, componentDefinition, maxComponentId)
	end

	ComponentDesc.NumParamsByComponentId = NumComponentParams
end


if script:WaitForChild("ComponentDefinitions", 2) then
	local componentDefinitions = require(script.ComponentDefinitions)

	populateDefs(componentDefinitions)

	if Constants.IS_STUDIO then
		script.ComponentDefinitions:GetPropertyChangedSignal("Source"):Connect(function()
			componentDefinitions = require(script.ComponentDefinitions:Clone())
			populateDefs(componentDefinitions)

			if ComponentDesc._defUpdateCallback then
				ComponentDesc._defUpdateCallback()
			end
		end)
	end
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
