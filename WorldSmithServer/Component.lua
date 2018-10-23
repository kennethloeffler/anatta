--[[//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Component.lua

Reason for this class is so metadata may be attached to components without it clogging up the entity-component and component-entity 
maps. I haven't fully implemented this feature yet; anyone wishing to do so before I do is welcome :)

Constructor:

	Component.new(Instance associatedInstance, string component, dictionary parameters)

Member variables:

	Public:

		Component.Model - this component's associated instance

	Private:

		(none)
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////--]]

local CollectionService = game:GetService("CollectionService")

local Component = {}
Component.__index = Component

function Component.new(associatedInstance, component, parameters)
	local instance = {}

	instance.Model = associatedInstance
	
	local parameterContainer = Instance.new("Folder")
	parameterContainer.Name = component
	
	for param, v in pairs(parameters) do
		if typeof(v) == "Instance" then
			local objRef = Instance.new("ObjectValue")
			objRef.Name = param
			objRef.Value = v
			objRef.Parent = parameterContainer
		elseif typeof(v) == "string" then
			local paramRef = Instance.new("StringValue")
			paramRef.Name = param
			paramRef.Value = v
			paramRef.Parent = parameterContainer
		elseif typeof(v) == "number" then
			local paramRef = Instance.new("NumberValue")
			paramRef.Name = param
			paramRef.Value = v
			paramRef.Parent = parameterContainer
		elseif typeof(v) == "boolean" then
			local paramRef = Instance.new("BoolValue")
			paramRef.Name = param
			paramRef.Value = v
			paramRef.Parent = parameterContainer
		end
	end
	
	parameterContainer.Parent = associatedInstance
	CollectionService:AddTag(associatedInstance, "entity")
	CollectionService:AddTag(parameterContainer, "component")
	
	return instance, parameterContainer
end

return Component
