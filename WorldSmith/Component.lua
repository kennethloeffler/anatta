-- Component.lua

local CollectionService = game:GetService("CollectionService")
local ComponentDesc = require(script.Parent.ComponentDesc)

local ComponentIds = {}
local ComponentParamId = {}

local Component = {}

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

function Component.new(entity, component, paramList, isStudio, isPlugin)
	assert(typeof(entity) == "Instance", "Expected instance")
	assert((typeof(component) == "number" or typeof(component) == "string", "Expected string or integer")
	assert(typeof(paramList) == "table", "Expected table")
	
	local struct = {} 
	local componentId = typeof(component) == "number" and component or Component._getComponentIdFromType(component)

	for paramName in pairs(ComponentDesc[componentId]) do
		local paramId = Component._getParamIdFromName(paramName)
		struct[paramId] = paramList[paramName]
	end
	
	local StructMetatable = {
		__index = function(_, index)
			local paramId = Component._getParamIdFromName(index, componentId)
			if paramId then
				return struct[paramId]
			elseif index == "Parent" then
				return entity
			elseif index == "_componentId" then
				return componentId
			else
				error(component .. " does not have parameter " .. index)	
			end
		end,
		__newindex = function(_, index, value)
			local paramId = Component._getParamIdFromName(index, componentId)
			if paramId then
				struct[paramId] = value
			else
				error(component .. " does not have parameter " .. index)
			end
		end
	}
	
	return setmetatable(struct, StructMetatable)
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

return Component
