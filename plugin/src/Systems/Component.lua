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
	local typeAllowed, result = typeDefinition:tryGetConcreteType()

	if not typeAllowed then
		error(("Failed to load component definition: %s"):format(result))
		return
	end

	local _, default = typeDefinition:tryDefault()
	local entitiesWithComponent = system:all(".anattaInstance", componentName):collect()
	local scheduledDestructions = system
		:all(".anattaScheduledDestruction", ".anattaInstance")
		:collect()
	local pendingAddition = {}
	local pendingRemoval = {}

	local function tagAdded(instance)
		pendingAddition[instance] = true
		pendingRemoval[instance] = nil
	end

	local function tagRemoved(instance)
		pendingAddition[instance] = nil
		pendingRemoval[instance] = true
	end

	local addedConnection = CollectionService
		:GetInstanceAddedSignal(componentName)
		:Connect(tagAdded)
	local removedConnection = CollectionService
		:GetInstanceRemovedSignal(componentName)
		:Connect(tagRemoved)

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
		addedConnection:Disconnect()
		removedConnection:Disconnect()

		for instance in pairs(pendingAddition) do
			CollectionService:RemoveTag(instance, componentName)
			tagAdded(instance)
		end

		for instance in pairs(pendingRemoval) do
			CollectionService:AddTag(instance, componentName)
			tagRemoved(instance)
		end

		-- All attribute and tag sets related to component addition and removal
		-- must be done in this waypoint in order for the invariants to hold
		-- after undos and redos.
		ChangeHistoryService:SetWaypoint("Processing Anatta component events")

		for instance in pairs(pendingAddition) do
			local entity = util.getValidEntity(registry, instance)
			registry:tryAdd(entity, componentName, default)
		end

		for instance in pairs(pendingRemoval) do
			if not util.tryGetValidEntityAttribute(registry, instance) then
				CollectionService:RemoveTag(instance, componentName)
				pendingRemoval[instance] = nil
				continue
			end

			local entity = util.getValidEntity(registry, instance)
			registry:tryRemove(entity, componentName)
		end

		scheduledDestructions:each(function(entity, scheduledDestruction)
			if tick() >= scheduledDestruction then
				registry:destroy(entity)
			end
		end)

		ChangeHistoryService:SetWaypoint("Processed Anatta component events")

		addedConnection = CollectionService:GetInstanceAddedSignal(componentName):Connect(tagAdded)
		removedConnection = CollectionService
			:GetInstanceRemovedSignal(componentName)
			:Connect(tagRemoved)
	end)

	system:on(entitiesWithComponent.added, function(entity, instance, component)
		registry:tryRemove(entity, ".anattaValidationListener")

		local _, attributeMap = Anatta.Dom.tryToAttribute(
			instance,
			component,
			componentName,
			typeDefinition
		)

		CollectionService:AddTag(instance, componentName)

		for attributeName, value in pairs(attributeMap) do
			if typeof(value) ~= "Instance" then
				instance:SetAttribute(attributeName, value)
			else
				instance:SetAttribute(attributeName, value:GetFullName())
			end
		end

		pendingAddition[instance] = nil

		registry:add(entity, ".anattaValidationListener")
		registry:tryRemove(entity, ".anattaScheduledDestruction")
	end)

	system:on(entitiesWithComponent.removed, function(entity, instance, component)
		local wasListening = registry:tryRemove(entity, ".anattaValidationListener")

		local _, attributeMap = Anatta.Dom.tryToAttribute(
			instance,
			component,
			componentName,
			typeDefinition
		)

		CollectionService:RemoveTag(instance, componentName)

		for attributeName, value in pairs(attributeMap) do
			instance:SetAttribute(attributeName, nil)

			if typeof(value) == "Instance" then
				instance.__anattaRefs[attributeName]:Destroy()

				if not next(instance.__anattaRefs:GetChildren()) then
					instance.__anattaRefs:Destroy()
				end
			end
		end

		pendingRemoval[instance] = nil

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

		if wasListening then
			registry:add(entity, ".anattaValidationListener")
		end

		registry:tryRemove(entity, pendingComponentValidation)
	end)
end
