local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Constants)

local getComponentDefinitions = require(script.Parent.Parent.getComponentDefinitions)
local tryToAttribute = require(script.Parent.Parent.Parent.Anatta.Library.util.tryToAttribute)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

local TagsAndAttributes = {}

function TagsAndAttributes:init()
	local registry = self.registry
	local system = self.system
	local componentDefinitions = getComponentDefinitions()

	for componentName, typeDefinition in pairs(componentDefinitions) do
		local tagComponentName = ("%sTag"):format(componentName)
		local attributeMap, failedAttributeName, failedType = tryToAttribute(componentName, typeDefinition)

		if failedType then
			warn(("%s (%s) cannot be turned into an attribute"):format(failedAttributeName, failedType))
			continue
		end

		registry:define(tagComponentName, function(arg)
			return arg:IsA("Instance")
		end)

		system:on(CollectionService:GetInstanceAddedSignal(componentName), function(instance)
			local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

			if entity ~= nil and registry:valid(entity) then
				if registry:get(entity, tagComponentName) ~= instance then
					-- The entity is valid, but it is already associated with a
					-- different instance. This can happen when a model file
					-- containing entities is inserted or when entities are
					-- cloned.
					entity = registry:create()
					instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, entity)
				end
			else
				entity = registry:create()
				instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, entity)
			end

			registry:add(entity, tagComponentName, instance)

			for attributeName, defaultValue in pairs(attributeMap) do
				instance:SetAttribute(attributeName, defaultValue)
			end
		end)

		system:on(CollectionService:GetInstanceRemovedSignal(componentName), function(instance)
			local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

			if registry:valid(entity) then
				registry:remove(entity, tagComponentName)

				if registry:stub(entity) then
					registry:destroy(entity)
				end
			end

			instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, nil)

			for attributeName in pairs(attributeMap) do
				instance:SetAttribute(attributeName, nil)
			end
		end)
	end
end

return TagsAndAttributes
