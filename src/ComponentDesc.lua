local WSAssert = require(script.Parent.WSAssert)

local ComponentDesc = {}

local ComponentIdsByType = {}
local ComponentTypesById = {}
local ComponentParamIds = {}
local CachedComponentIds = script:GetChildren()

ComponentDesc._numUniqueComponents = #CachedComponentIds

local function cacheComponentId(componentTypeName, componentId)
	local valueObject = Instance.new("IntValue")
	valueObject.Value = componentId
	valueObject.Name = componentTypeName
	valueObject.Parent = script
end

local function cacheParamId(componentTypeName, paramName, paramId)
	local valueObject = Instance.new("IntValue")
	valueObject.Value = paramId
	valueObject.Name = paramName
	valueObject.Parent = script[componentTypeName]
end

---Defines a new component type with name componentType with parameters defined by paramMap
-- @param componentType A human-readable type name for this component
-- @param paramMap A dictionary containing parameter type and default value information
-- @return The component id of this component
function ComponentDesc.Define(componentType, paramMap)
	WSAssert(typeof(componentTypeName) == "string")
	WSAssert(typeof(paramMap) == "table"))
	
	local cachedComponentIdObject = script:FindFirstChild(componentTypeName)
	local componentId = cachedComponentIdObject and cachedComponentIdObject.Value or ComponentDesc._numUniqueComponents + 1
	ComponentIdsByType[componentId] = componentTypeName
	ComponentTypesById[componentTypeName] = componentId
	ComponentParamIds[componentId] = {}
	
	local paramId = 0
	for paramName in pairs(paramMap) do
		WSAssert(typeof(paramName) == "string")
		paramId = cachedComponentIdObject and cachedComponentIdObject[paramName].Value or paramId + 1
		ComponentParamIds[componentId][paramName] = paramId
	end
	
	ComponentDesc._numUniqueComponents = ComponentDesc._numUniqueComponents + (cachedComponentIdObject and 0 or 1)
	
	return componentId
end

function ComponentDesc.GetParamIdFromName(componentId, paramName)
	return ComponentParamIds[componentId][paramName] or error(paramName .. " is not a valid parameter name")
end

function ComponentDesc.GetComponentIdFromType(componentType)
	return ComponentIdsByType[componentType] or error(componentType .. " is not a valid ComponentType")
end

function ComponentDesc.GetComponentTypeFromId(componentId)
	return ComponentTypesById[componentId] or error(componentId .. " is not a valid component id"
end

return ComponentDesc
