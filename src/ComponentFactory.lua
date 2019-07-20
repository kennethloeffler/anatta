-- ComponentFactory.lua

local ComponentDesc = require(script.Parent.ComponentDesc)
local WSAssert = require(script.Parent.WSAssert)

local ComponentMetatable = {
	__index = function(component, index)
		local paramId = ComponentDesc.GetParamIdFromName(component._componentId, index)
		return component[paramId]
	end,
	__newindex = function(component, index, value)
		local componentId = component._componentId
		local paramId = ComponentDesc.GetParamIdFromName(componentId, index)
		local ty = typeof(ComponentDesc.GetParamDefault(componentId, paramId))
		WSAssert(ty == typeof(value), "expected %s", ty)
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
	
	for paramName, default in pairs(ComponentDesc.GetDefaults(componentId)) do
		local paramId = ComponentDesc.GetParamIdFromName(componentId, paramName)
		newComponent[paramId] = paramMap[paramName] or default
	end
	
	return setmetatable(newComponent, ComponentMetatable)
end

return Component

