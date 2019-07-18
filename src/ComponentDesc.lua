local WSAssert = require(script.Parent.WSAssert)

local ComponentIdsByType = {}
local ComponentTypesById = {}
local ComponentParamIds = {}

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
	
		for paramName, paramId in pairs(componentDefinition) do
			if paramName ~= "ComponentId" then
				WSAssert(typeof(paramName) == "string", "expected string")
				WSAssert(typeof(paramId) == "number", "expected number")
				ComponentParamIds[componentId][paramName] = paramId
			end
		end
	end
	ComponentDesc.ComponentDefinitions = definitionTable
end

if script:FindFirstChild("ComponentDefinitions") then 
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

function ComponentDesc.GetParamIdFromName(componentId, paramName)
	return ComponentParamIds[componentId][paramName] or error(paramName .. " is not a valid parameter name", 3)
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

function ComponentDesc.GetAllParams(componentType)
	local componentId = ComponentIdsByType[componentType]
	return ComponentParamIds[componentType]
end

return ComponentDesc
