local CollectionService = game:GetService("CollectionService")

local Anatta = require(script.Parent.Parent.Anatta)

local getComponentDefinitions = require(script.Parent.getComponentDefinitions)
local tryGetAttributes = require(script.Parent.Parent.Anatta.src.util.tryGetAttributes)

return function(plugin)
	local componentDefinitions = getComponentDefinitions()
	local anatta = Anatta.define(componentDefinitions)
	local registry = anatta.registry

	for componentName, typeDefinition in pairs(componentDefinitions) do
		local tagComponentName = ("%sTag"):format(componentName)
		local attributeMap, failedAttributeName, failedType = tryGetAttributes(componentName, typeDefinition)

		if failedType then
			warn(("%s (%s) cannot be turned into an attribute"):format(failedAttributeName, failedType))
			continue
		end

		registry:define(tagComponentName, function(arg)
			return arg == nil
		end)
		CollectionService:GetInstanceAddedSignal(componentName):Connect(function(instance)
			local entity = instance:GetAttribute("EntityId")

			if entity ~= nil then
				if not registry:valid(entity) then
					-- This can happen when a model file containing entities is
					-- inserted or when entities are cloned.
					entity = registry:create()
					instance:SetAttribute("EntityId", entity)
				end
			else
				entity = registry:create()
				instance:SetAttribute("EntityId", entity)
			end

			registry:add(entity, tagComponentName)

			for attributeName, defaultValue in pairs(attributeMap) do
				instance:SetAttribute(attributeName, defaultValue)
			end
		end)

		CollectionService:GetInstanceRemovedSignal(componentName):Connect(function(instance)
			local entity = instance:GetAttribute("EntityId")

			registry:remove(entity, tagComponentName)

			if registry:stub(entity) then
				registry:destroy(entity)
				instance:SetAttribute("EntityId", nil)

				for attributeName, defaultValue in pairs(attributeMap) do
					instance:SetAttribute(attributeName, nil)
				end
			end
		end)
	end
end
