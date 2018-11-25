--[[///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	Component factory
	
--]]--/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



local CollectionService = game:GetService("CollectionService")
local ComponentDesc = require(script.Parent.ComponentDesc)

local Component = {}
Component.__index = Component

local ComponentIds = {}
local ComponentParamId = {}

-- serialization doo dads
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
	
	local struct = {}
	
	local componentId = tonumber(component) or Component:_getComponentIdFromType(component)
	local parameterContainer

	if isPlugin then
		parameterContainer = Instance.new("Folder")
		CollectionService:AddTag(parameterContainer, "component")
		parameterContainer.Name = componentId
		parameterContainer.Parent = entity
		for param, v in pairs(paramList) do
			local paramId = Component:_getParamIdFromName(param, componentId)
			local paramRef
			if typeof(v) == "Instance" then
				paramRef = Instance.new("ObjectValue")
			elseif typeof(v) == "string" then
				paramRef = Instance.new("StringValue")
			elseif typeof(v) == "number" then
				paramRef = Instance.new("NumberValue")
			elseif typeof(v) == "boolean" then
				paramRef = Instance.new("BoolValue")
			end
			paramRef.Name = param
			paramRef.Value = v
			paramRef.Parent = parameterContainer
			struct[paramId] =  v
			entity[componentId][param]:GetPropertyChangedSignal("Value"):connect(function()
				rawset(struct, paramId, entity[componentId][param].Value)
			end)
		end
	else
		for param, v in pairs(paramList) do
			local paramId = Component:_getParamIdFromName(param, componentId)
			struct[paramId] =  v
			if isStudio then
				entity[componentId][param]:GetPropertyChangedSignal("Value"):connect(function()
					rawset(struct, paramId, entity[componentId][param].Value)
				end)
			end	
		end
	end
			
	local StructMetatable = {
		__index = function(_, index)
			local paramId = Component:_getParamIdFromName(index, componentId)
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
			local paramId = Component:_getParamIdFromName(index, componentId)
			if paramId then
				struct[paramId] = value
				if isStudio then
					entity[componentId][index].Value = value
				end
			else
				error(component .. " does not have parameter " .. index)
			end
		end
	}
	
	return setmetatable(struct, StructMetatable)
end

function Component:_getComponentDesc() -- used by plugin
	return ComponentDesc
end

function Component:_getComponentIdFromType(componentType)
	return ComponentIds[componentType]
end

function Component:_getParamIdFromName(paramName, componentId)
	return ComponentParamId[componentId][paramName]
end

function Component:_getParamNameFromId(paramId, componentId)
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
