-- ComponentFactory.lua

local ComponentDesc = require(script.Parent.ComponentDesc)
local WSAssert = require(script.Parent.WSAssert)

local ComponentMetatable = {
	__index = function(component, index)
		local paramId = ComponentDesc.GetParamIdFromName(component._componentId, index)
		return component[paramId]
	end,
	__newindex = function(component, index, value)
		local paramId = ComponentDesc.GetParamIdFromName(component._componentId, index)
		component[paramId] = value
	end
}

---Instantiates a new component of type componentType on the entity attached to instance with parameters defined by paramMap
--@param instance
--@param componentType
--@param paramMap
--@return The new component object
function Component(instance, entity, componentType, paramMap)
	local newComponent = {} 

	local componentId = ComponentDesc.GetComponentIdFromType(componentType)

	newComponent._componentId = componentId
	newComponent._entity = entity
	newComponent.Instance = instance
	
	if paramMap then
		for paramName in pairs(paramMap) do
			local paramId = ComponentDesc.GetParamIdFromName(componentId, paramName)
			newComponent[paramId] = paramMap[paramName]
		end
	else
		for paramId, default in pairs(ComponentDesc.GetDefaults(componentId)) do
			newComponent[paramId] = default
		end
	end
	
	return setmetatable(newComponent, ComponentMetatable)
end

return Component

