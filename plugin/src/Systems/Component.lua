local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)
local Constants = require(script.Parent.Parent.Constants)
local util = require(script.Parent.util)

local SECONDS_BEFORE_DESTRUCTION = Constants.SecondsBeforeDestruction
local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local PLUGIN_PRIVATE_COMPONENT_PREFIX = Constants.PluginPrivateComponentPrefix

return function(system, registry, componentName, pendingComponentValidation)
	local withComponent = system:all(".anattaInstance", componentName):collect()
	local scheduledDestructions = system
		:all(".anattaInstance", ".anattaScheduledDestruction")
		:collect()

	local typeDefinition = registry:getDefinition(componentName)
	local default = typeDefinition:default()
	local pendingAddition = {}
	local pendingRemoval = {}

	system:on(withComponent.added, function(entity, instance, component)
		registry:tryRemove(entity, ".anattaValidationListener")

		local success, attributeMap = Anatta.Dom.tryToAttribute(
			component,
			componentName,
			typeDefinition
		)

		if not success then
			warn(attributeMap)
		end

		CollectionService:AddTag(instance, componentName)
		instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, entity)

		for attributeName, value in pairs(attributeMap) do
			instance:SetAttribute(attributeName, value)
		end

		pendingAddition[instance] = nil

		registry:add(entity, ".anattaValidationListener")
		registry:tryRemove(entity, ".anattaScheduledDestruction")
	end)

	system:on(withComponent.removed, function(entity, instance, component)
		local wasListening = registry:tryRemove(entity, ".anattaValidationListener")

		local success, attributeMap = Anatta.Dom.tryToAttribute(
			component,
			componentName,
			typeDefinition
		)

		if not success then
			warn(attributeMap)
		end

		CollectionService:RemoveTag(instance, componentName)

		for attributeName in pairs(attributeMap) do
			instance:SetAttribute(attributeName, nil)
		end

		if
			registry:visit(function(visitedComponentName)
				if
					visitedComponentName ~= componentName
					and not visitedComponentName:find(PLUGIN_PRIVATE_COMPONENT_PREFIX)
				then
					return true
				end
			end, entity) == nil
		then
			if instance.Parent ~= nil then
				registry:add(entity, ".anattaScheduledDestruction", tick())
			else
				registry:tryAdd(
					entity,
					".anattaScheduledDestruction",
					tick() + SECONDS_BEFORE_DESTRUCTION
				)
			end
		end

		pendingRemoval[instance] = nil

		if wasListening then
			registry:add(entity, ".anattaValidationListener")
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
		end

		for instance in pairs(pendingRemoval) do
			local entity = util.getValidEntity(registry, instance)

			registry:tryRemove(entity, componentName)
		end

		scheduledDestructions:each(function(entity, instance, scheduledDestruction)
			if tick() >= scheduledDestruction then
				registry:destroy(entity)
				instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, nil)
			end
		end)
	end)
end
