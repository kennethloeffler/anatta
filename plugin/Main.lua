local CollectionService = game:GetService("CollectionService")

local Anatta = require(script.Parent.Parent.Anatta)

local getComponentDefinitions = require(script.Parent.getComponentDefinitions)
local tryGetAttributes = require(script.Parent.Parent.Anatta.util.tryGetAttributes)

return function(plugin)
	local componentDefinitions = getComponentDefinitions()
	local anatta = Anatta:define(componentDefinitions)
	local registry = anatta.registry

	for componentName, typeDefinition in pairs(componentDefinitions) do
		local attributeMap, failedAttributeName, failedType = tryGetAttributes(typeDefinition)

		if failedType then
			warn(("%s (%s) cannot be turned into an attribute"):format(failedAttributeName, failedType))
			continue
		end

		CollectionService:GetInstanceAddedSignal(componentName):Connect(function(instance)
			local entity = instance:GetAttribute("EntityId")

			if entity ~= nil then
				if not registry:valid(entity) then
					-- This can happen when a model file containing entities is
					-- inserted or when entities are cloned.
					instance:SetAttribute("EntityId", registry:create())
				end
			else
				instance:SetAttribute("EntityId", registry:create())
			end

			for attributeName, defaultValue in pairs(attributeMap) do
				registry:add(entity, componentName, defaultValue)
				instance:SetAttribute(attributeName, defaultValue)
			end
		end)

		CollectionService:GetInstanceRemovedSignal(componentName):Connect(function(instance)
			local entity = instance:GetAttribute("EntityId")

			registry:remove(entity, componentName)

			if registry:stub(entity) then
				registry:destroy(entity)
				instance:SetAttribute("EntityId", nil)
			end
		end)
	end
end
