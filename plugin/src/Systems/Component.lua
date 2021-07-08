local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)
local Constants = require(script.Parent.Parent.Constants)
local util = require(script.Parent.util)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local PLUGIN_PRIVATE_COMPONENT_PREFIX = Constants.PluginPrivateComponentPrefix

return function(system, registry, componentName, pendingComponentValidation)
	local pendingAddition = {}
	local pendingRemoval = {}

	local allWithComponent = system:all("__anattaPluginInstance", componentName):collect()
	local typeDefinition = registry:getDefinition(componentName)
	local default = typeDefinition:default()

	system:on(allWithComponent.added, function(entity, instance, component)
		CollectionService:AddTag(instance, componentName)
		pendingAddition[instance] = nil

		registry:tryRemove(entity, "__anattaPluginValidationListener")

		local success, attributeMap = Anatta.Dom.tryToAttribute(
			component,
			componentName,
			typeDefinition
		)

		if not success then
			warn(attributeMap)
		end

		for attributeName, value in pairs(attributeMap) do
			instance:SetAttribute(attributeName, value)
		end

		registry:add(entity, "__anattaPluginValidationListener")
	end)

	system:on(allWithComponent.removed, function(entity, instance, component)
		CollectionService:RemoveTag(instance, componentName)
		pendingRemoval[instance] = nil

		local wasListening = registry:tryRemove(entity, "__anattaPluginValidationListener")

		local success, attributeMap = Anatta.Dom.tryToAttribute(
			component,
			componentName,
			typeDefinition
		)

		if not success then
			warn(attributeMap)
		end

		for attributeName in pairs(attributeMap) do
			instance:SetAttribute(attributeName, nil)
		end

		if wasListening then
			registry:add(entity, "__anattaPluginValidationListener")
		end

		registry:tryRemove(entity, pendingComponentValidation)
	end)

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
			local entity = util.getValidEntity(registry, instance)
			local existing = registry:get(entity, componentName)

			registry:tryAdd(entity, componentName, existing or default)
			pendingAddition[instance] = nil
		end

		for instance in pairs(pendingRemoval) do
			local entity = util.getValidEntity(registry, instance)

			registry:tryRemove(entity, componentName)

			if
				registry:visit(function(visitedComponentName)
					if not visitedComponentName:find(PLUGIN_PRIVATE_COMPONENT_PREFIX) then
						return true
					end
				end, entity) == nil
			then
				registry:destroy(entity)
				instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, nil)
			end

			pendingRemoval[instance] = nil
		end
	end)
end
