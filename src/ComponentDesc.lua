local WSAssert = require(script.Parent.WSAssert)

local ComponentDesc = {}

local ComponentIdsByType = {}
local ComponentTypesById = {}
local ComponentParamIds = {}

function ComponentDesc.LoadComponentDescriptor()
   
	if not script:FindFirstChild("ComponentDescriptor") then
		ComponentDesc.ComponentDescriptor = {}
		return
	end

	local ComponentDescriptorModule = script.ComponentDescriptor:Clone()
	script.ComponentDescriptor:Destroy()
	ComponentDescriptorModule.Parent = script
	
	local ComponentDescriptor = require(ComponentDescriptorModule)
	ComponentDesc.ComponentDescriptor = ComponentDescriptor
	
	for componentType, componentData in pairs(ComponentDescriptor) do

		WSAssert(typeof(componentType) == "string", "expected string")
		WSAssert(typeof(componentData) == "table", "expected table")
	
		local componentId = componentData.ComponentId
		WSAssert(componentId ~= nil and typeof(componentId) == "number" and math.floor(componentId) == componentId, "expected number")
		ComponentIdsByType[componentType] = componentId
		ComponentTypesById[componentId] = componentType
		ComponentParamIds[componentId] = {}
	
		for paramName, paramId in pairs(componentData) do
			if paramName ~= "ComponentId" then
				WSAssert(paramName == "string", "expected string")
				WSAssert(paramId == "number", "expected number")
				ComponentParamIds[componentId][paramName] = paramId
			end
		end
	end
end

function ComponentDesc.GetParamIdFromName(componentId, paramName)
	return ComponentParamIds[componentId][paramName] or error(paramName .. " is not a valid parameter name")
end

function ComponentDesc.GetComponentIdFromType(componentType)
	return ComponentIdsByType[componentType] or error(componentType .. " is not a valid ComponentType")
end

function ComponentDesc.GetComponentTypeFromId(componentId)
	return ComponentTypesById[componentId] or error(componentId .. " is not a valid component id")
end

return ComponentDesc
