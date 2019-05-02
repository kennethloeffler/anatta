-- Component.lua

local CollectionService = game:GetService("CollectionService")
local ComponentDesc = require(script.Parent.ComponentDesc)

local Component = {}

local ComponentIds = {}
local ComponentParamId = {}

local ComponentMetatable = {
	__index = function(component, index)
		local paramId = Component._getParamIdFromName(index, component.componentId)
		if paramId then
			return component[paramId]
		elseif index == "Parent" then
			return component._entity
		elseif index == "_componentId" then
			return component._componentId
		else
			error(" does not have parameter " .. index)	
		end
	end,
	__newindex = function(component, index, value)
		local paramId = Component._getParamIdFromName(index, component._componentId)
		if paramId then
			component[paramId] = value
		else
			error(" does not have parameter " .. index)
		end
	end
}

function Component.new(entity, component, paramList)
	assert(typeof(entity) == "Instance", "Expected instance")
	assert(typeof(component) == "number" or typeof(component) == "string", "Expected string or integer")
	assert(typeof(paramList) == "table", "Expected table")
	
	local newComponent = {} 
	newComponent._componentId = typeof(component) == "number" and component or Component._getComponentIdFromType(component)
	newComponent._entity = entity
	
	for paramName in pairs(ComponentDesc[componentId]) do
		local paramId = Component._getParamIdFromName(paramName)
		newComponent[paramId] = paramList[paramName]
	end
	
	return setmetatable(newComponent, ComponentMetatable)
end

function Component._getComponentDesc() -- used by plugin
	return ComponentDesc
end

function Component._getComponentIdFromType(componentType)
	return ComponentIds[componentType]
end

function Component._getParamIdFromName(paramName, componentId)
	return ComponentParamId[componentId][paramName]
end

function Component._getParamNameFromId(paramId, componentId)
	local params = ComponentParamId[componentId]
	local retParamName
	for paramName, id in pairs(params) do
		if id == paramId then
			retParamName = paramName
		end
	end
	return retParamName
end

-- set up tables for looking up components by id/typenames
for id, component in ipairs(ComponentDesc) do
	if component._metadata then
		if component._metadata.ComponentType then
			ComponentIds[component._metadata.ComponentType] = id
		else
			warn("game.ReplicatedStorage.Component: ._metadata for ComponentId " .. id .. " is missing a 'ComponentType' field") 
		end
	else
		warn("game.ReplicatedStorage.Component: no ._metadata found for ComponentId " .. id)
	end
	local counter = 0
	ComponentParamId[id] = {}
	for paramName, v in pairs(component) do
		if typeof(v) == "string" then
			counter = counter + 1
			ComponentParamId[id][paramName] = counter
		end
	end
end

return Component
