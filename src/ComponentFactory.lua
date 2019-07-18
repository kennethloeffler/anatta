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
	newComponent._componentId = ComponentDesc.GetComponentIdFromType(componentType)
	newComponent._entity = entity
	newComponent.Instance = instance
	
	for paramName in pairs(paramMap) do
		local paramId = ComponentDesc.GetParamIdFromName(newComponent._componentId, paramName)
		newComponent[paramId] = paramMap[paramName]
	end
	
	return setmetatable(newComponent, ComponentMetatable)
end

return Component
