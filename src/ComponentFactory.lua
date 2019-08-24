-- ComponentFactory.lua
local CollectionService = game:GetService("CollectionService")
local
local Constants = require(scipt.Parent.EntityReplicator.Constants)
local ReplicatorShared = require(script.Parent.EntityReplicator.Shared)

local PARAMS_UPDATE = Constants.PARAMS_UPDATE
local IS_SERVER = Constants.IS_SERVER

local queue = ReplicatorShared.Queue

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

		if CollectionService:HasTag(instance, "__WSReplicatorRef") then
			queue(component.Instance, PARAMS_UPDATE, componentId, paramId)
		end
	end
}

---Instantiates a new component of type componentType on the entity attached to instance with parameters defined by paramMap.

-- If performance is a concern, then it is better for paramMap to be a contigous array (where each numeric index represents
-- a paramId). This not only removes loop overhead, but also avoids the cost of rehashing paramMap when the numeric keys are
-- inserted.

-- To also avoid the two rehashes when assigning to ._componentId and .Instance, one may assign values to these same indices
-- (the values don't particularly matter; the number 0 would suffice) when supplying paramMap to EntityManager.AddComponent().

-- As with any optimization, only do this when absolutely necessary; it will heavily reduce readability. It may be helpful to
-- include a comment in the system which indicates which parameter names go with which paramIds.

--@param instance Instance
--@param componentType string
--@param paramMap table
--@return The new component object

function Component(instance, componentType, paramMap)
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local newComponent = paramMap

	if #newComponent == 0 then
		for paramName, default in pairs(ComponentDesc.GetDefaults(componentId)) do
			local paramId = ComponentDesc.GetParamIdFromName(componentId, paramName)

			if newComponent[paramName] ~= nil then
				newComponent[paramId] = newComponent[paramName]
				newComponent[paramName] = nil
			else
				paramMap[paramId] = default
			end
		end
	end

	newComponent._componentId = componentId
	newComponent.Instance = instance

	setmetatable(newComponent, ComponentMetatable)

	if CollectionService:HasTag(instance, "__WSReplicatorRef") then
		queue(instance, ADD_COMPONENT, componentId)
	end

	return newComponent
end

return Component

