-- ComponentFactory.lua
local CollectionService = game:GetService("CollectionService")

local ComponentDesc = require(script.Parent.ComponentDesc)
local Constants = require(script.Parent.Constants)

local PARAMS_UPDATE = Constants.PARAMS_UPDATE
local ADD_COMPONENT = Constants.ADD_COMPONENT
local SHOULD_SEND = Constants.IS_SERVER or Constants.IS_CLIENT

local Replicator = SHOULD_SEND and require(script.Parent.EntityReplicator.Shared)

local GetComponentIdFromType = ComponentDesc.GetComponentIdFromType
local GetListTyped = ComponentDesc.GetListTyped
local GetParamIdFromName = ComponentDesc.GetParamIdFromName
local GetParamDefault = ComponentDesc.GetParamDefault
local GetDefaults = ComponentDesc.GetDefaults

local QueueUpdate = Replicator and Replicator.QueueUpdate
local BlackListed = Replicator and Replicator.GetBlacklistedComponents()

local ComponentMetatable = {
	__index = function(component, index)
		local paramId = GetParamIdFromName(component._componentId, index)
		return component[paramId]
	end,

	__newindex = function(component, index, value)
		local componentId = component._componentId
		local paramId = GetParamIdFromName(componentId, index)
		local ty = typeof(GetParamDefault(componentId, paramId))

		if not ty == typeof(value) then
			error("expected " .. ty)
		end

		component[paramId] = value

		if SHOULD_SEND and CollectionService:HasTag(component.Instance, "__WSReplicatorRef") and not BlackListed[componentId] then
			QueueUpdate(component.Instance, PARAMS_UPDATE, componentId, paramId)
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

return function(instance, componentType, paramMap)
	local componentId = typeof(componentType) == "number" and componentType or GetComponentIdFromType(componentType)
	local newComponent = paramMap or {}

	if not paramMap or not paramMap[1] then
		for paramName, default in pairs(GetDefaults(componentId)) do
			local paramId = GetParamIdFromName(componentId, paramName)

			if newComponent and newComponent[paramName] then
				newComponent[paramId] = newComponent[paramName]
				newComponent[paramName] = nil
			else
				newComponent[paramId] = default
			end
		end
	end

	newComponent._componentId = componentId
	newComponent._list = GetListTyped(componentId)
	newComponent.Instance = instance

	setmetatable(newComponent, ComponentMetatable)

	if SHOULD_SEND and CollectionService:HasTag(instance, "__WSReplicatorRef") and not BlackListed[componentId] then
		QueueUpdate(instance, ADD_COMPONENT, componentId)
	end

	return newComponent
end
