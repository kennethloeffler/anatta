local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)
local Constants = require(script.Parent.Parent.Constants)
local util = require(script.Parent.util)

local SECONDS_BEFORE_DESTRUCTION = Constants.SecondsBeforeDestruction
local PLUGIN_PRIVATE_COMPONENT_PREFIX = Constants.PluginPrivateComponentPrefix

return function(system, registry, componentName, pendingComponentValidation)
	local typeDefinition = registry:getDefinition(componentName)
	local defaultSuccess, default = typeDefinition:tryDefault()

	if not defaultSuccess then
		error(default)
	end

	local entitiesWithComponent = system:all(".anattaInstance", componentName):collect()
	local scheduledDestructions = system:all(".anattaScheduledDestruction"):collect()
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
		if
			not (
				next(pendingAddition)
				or next(pendingRemoval)
				or registry:count(".anattaScheduledDestruction") > 0
			)
		then
			return
		end

		-- The system is driven by CollectionService added/removed signals. A
		-- change history waypoint is created for any tag set, even without
		-- calls to ChangeHistoryService:SetWaypoint. To make sure the
		-- invariants hold after undos and redos, we need to remove any added
		-- tags and add any removed tags before recording the waypoint.
		for instance in pairs(pendingAddition) do
			CollectionService:RemoveTag(instance, componentName)
			pendingAddition[instance] = true
			pendingRemoval[instance] = nil
		end

		for instance in pairs(pendingRemoval) do
			CollectionService:AddTag(instance, componentName)
			pendingAddition[instance] = nil
			pendingRemoval[instance] = true
		end

		-- All attribute and tag sets related to component addition and removal
		-- must be done in this waypoint in order for the invariants to hold
		-- after undos and redos.
		ChangeHistoryService:SetWaypoint("Processing Anatta component events")

		for instance in pairs(pendingAddition) do
			local entity = util.getValidEntity(registry, instance)
			registry:add(entity, componentName, default)
		end

		for instance in pairs(pendingRemoval) do
			local entity = util.getValidEntity(registry, instance)
			registry:tryRemove(entity, componentName)
		end

		scheduledDestructions:each(function(entity, scheduledDestruction)
			if tick() >= scheduledDestruction and registry:valid(entity) then
				registry:destroy(entity)
			end
		end)

		ChangeHistoryService:SetWaypoint("Processed Anatta component events")
	end)

	system:on(entitiesWithComponent.added, function(entity, instance, component)
		registry:tryRemove(entity, ".anattaValidationListener")

		local _, attributeMap = Anatta.Dom.tryToAttribute(component, componentName, typeDefinition)

		CollectionService:AddTag(instance, componentName)

		for attributeName, value in pairs(attributeMap) do
			instance:SetAttribute(attributeName, value)
		end

		pendingAddition[instance] = nil

		registry:add(entity, ".anattaValidationListener")
		registry:tryRemove(entity, ".anattaScheduledDestruction")
	end)

	system:on(entitiesWithComponent.removed, function(entity, instance, component)
		local wasListening = registry:tryRemove(entity, ".anattaValidationListener")

		local _, attributeMap = Anatta.Dom.tryToAttribute(component, componentName, typeDefinition)

		CollectionService:RemoveTag(instance, componentName)

		for attributeName in pairs(attributeMap) do
			instance:SetAttribute(attributeName, nil)
		end

		if
			not registry:visit(function(visitedComponentName)
				if
					visitedComponentName ~= componentName
					and not visitedComponentName:find(PLUGIN_PRIVATE_COMPONENT_PREFIX)
				then
					return true
				end
			end, entity)
		then
			if instance.Parent ~= nil then
				registry:tryAdd(entity, ".anattaScheduledDestruction", tick())
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
end
