local WSAssert = require(script.Parent.WSAssert)

local ComponentIdsByType = {}
local ComponentTypesById = {}
local ComponentParamIds = {}
local Defaults = {}

local ComponentDesc = {
	ComponentDefinitions = {},
	_defUpdateCallback = nil
}

local function populateDefs(definitionTable)
	for componentType, componentDefinition in pairs(definitionTable) do

		WSAssert(typeof(componentType) == "string", "expected string")
		WSAssert(typeof(componentDefinition) == "table", "expected table")
	
		local componentId = componentDefinition.ComponentId
		WSAssert(componentId ~= nil and typeof(componentId) == "number" and math.floor(componentId) == componentId, "expected number")
		ComponentIdsByType[componentType] = componentId
		ComponentTypesById[componentId] = componentType
		ComponentParamIds[componentId] = {}
		Defaults[componentId] = {}
	
		for paramName, paramDef in pairs(componentDefinition) do
			if paramName ~= "ComponentId" then
				WSAssert(typeof(paramName) == "string", "expected string")
				WSAssert(typeof(paramDef) == "table", "expected table")
				ComponentParamIds[componentId][paramName] = paramDef[1]
				Defaults[componentId][paramName] = paramDef[2]
			end
		end
	end
	ComponentDesc.ComponentDefinitions = definitionTable
end

if script:WaitForChild("ComponentDefinitions", 1) then 
	local componentDefinitions = require(script.ComponentDefinitions)
	populateDefs(componentDefinitions)
	script.ComponentDefinitions.Changed:Connect(function(prop)
		if prop ~= "Source" then
			return
		end
		populateDefs(require(script.ComponentDefinitions:Clone()))
		if ComponentDesc._defUpdateCallback then
			ComponentDesc._defUpdateCallback()
		end
	end)	
end

function ComponentDesc.GetDefaults(componentId)
	return Defaults[componentId]
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

return ComponentDesc

