local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Constants)
local util = require(script.Parent.Parent.Parent.Anatta.Library.util)

local getValidEntity = require(script.Parent.Parent.getValidEntity)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local DEFINITION_MODULE_TAG_NAME = Constants.DefinitionModuleTagName
local PRIVATE_COMPONENT_PREFIX = Constants.PrivateComponentPrefix

local Components = {}

function Components:init()
	local registry = self.registry
	local system = self.system

	local function loadDefinitions(moduleScript)
		if not moduleScript:IsA("ModuleScript") then
			warn(("Components definition instance %s must be a ModuleScript"):format(moduleScript:GetFullName()))
			return
		end

		local componentDefinitions = require(moduleScript)

		for componentName, typeDefinition in pairs(componentDefinitions) do
			if registry:hasDefined(componentName) then
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

			registry:define(componentName, function(arg)
				return arg == nil
			end)

			registry:getPools(componentName)[1].typeDefinition = typeDefinition

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
					local entity = getValidEntity(registry, instance)

					pendingAddition[instance] = nil
					registry:add(entity, componentName)

					registry:tryRemove(entity, "__anattaValidate")

					for attributeName, defaultValue in pairs(attributeMap) do
						instance:SetAttribute(attributeName, defaultValue)
					end

					registry:add(entity, "__anattaValidate")
				end

				for instance in pairs(pendingRemoval) do
					local entity = getValidEntity(registry, instance)

					pendingRemoval[instance] = nil
					registry:remove(entity, componentName)

					local isStub = true

					registry:visit(function(name)
						if not name:find(PRIVATE_COMPONENT_PREFIX) then
							isStub = false
						end
					end, entity)

					registry:tryRemove(entity, "__anattaValidate")

					for attributeName in pairs(attributeMap) do
						instance:SetAttribute(attributeName, nil)
					end

					if isStub then
						registry:destroy(entity)
						instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, nil)
					else
						registry:add(entity, "__anattaValidate")
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

return Components