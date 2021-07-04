local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Constants)
local util = require(script.Parent.Parent.Parent.Anatta.Library.util)

local getValidEntity = require(script.Parent.Parent.getValidEntity)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local DEFINITION_MODULE_TAG_NAME = Constants.DefinitionModuleTagName
local PRIVATE_COMPONENT_PREFIX = Constants.PrivateComponentPrefix

local Attributes = {}

function Attributes:init()
	local registry = self.registry
	local system = self.system

	local function loadDefinitions(moduleScript)
		if not moduleScript:IsA("ModuleScript") then
			warn(("Components definition instance %s must be a ModuleScript"):format(moduleScript:GetFullName()))
			return
		end

		local componentDefinitions = require(moduleScript)

		for componentName, typeDefinition in pairs(componentDefinitions) do
			local tagComponentName = ("%sTag"):format(componentName)

			if registry:hasDefined(tagComponentName) then
				warn(("Found duplicate component name %s in %s; skipping"):format(
					componentName,
					moduleScript:GetFullName()
				))
				continue
			end

			local attributeMap, failedAttributeName, failedType = util.tryToAttribute(componentName, typeDefinition)

			if failedType then
				warn(("%s (%s) cannot be turned into an attribute"):format(failedAttributeName, failedType))
				continue
			end

			registry:define(tagComponentName, function(arg)
				return arg == nil
			end)

			local pendingAddition = {}
			local pendingRemoval = {}

			system:on(CollectionService:GetInstanceAddedSignal(componentName), function(instance)
				pendingAddition[instance] = true
				pendingRemoval[instance] = nil
			end)

			system:on(CollectionService:GetInstanceRemovedSignal(componentName), function(instance)
				pendingAddition[instance] = nil
				pendingRemoval[instance] = true
			end)

			system:on(RunService.Heartbeat, function()
				for instance in pairs(pendingAddition) do
					pendingAddition[instance] = nil
					local entity = getValidEntity(registry, instance)

					registry:add(entity, tagComponentName)
					registry:tryAdd(entity, "__anattaSelected")

					for attributeName, defaultValue in pairs(attributeMap) do
						instance:SetAttribute(attributeName, defaultValue)
					end
				end

				for instance in pairs(pendingRemoval) do
					pendingRemoval[instance] = nil
					local entity = getValidEntity(registry, instance)

					registry:remove(entity, tagComponentName)

					local isStub = true

					registry:visit(function(name)
						if not name:find(PRIVATE_COMPONENT_PREFIX) then
							isStub = false
						end
					end, entity)

					if isStub then
						registry:destroy(entity)
						instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, nil)
					end

					for attributeName in pairs(attributeMap) do
						instance:SetAttribute(attributeName, nil)
					end
				end
			end)
		end
	end

	for _, moduleScript in ipairs(CollectionService:GetTagged(DEFINITION_MODULE_TAG_NAME)) do
		loadDefinitions(moduleScript)
	end

	system:on(CollectionService:GetInstanceAddedSignal(DEFINITION_MODULE_TAG_NAME), loadDefinitions)
end

return Attributes
