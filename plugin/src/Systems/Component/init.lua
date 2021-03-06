-- System that adds and removes instance attributes corresponding to an entity
-- and a component type when tags are added or removed from an instance.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local util = require(script.Parent.util)

local add = require(script.addComponent)
local remove = require(script.removeComponent)

return function(system, registry, componentName, pendingComponentValidation)
	local typeDefinition = registry:getDefinition(componentName)
	local typeAllowed, result = typeDefinition:tryGetConcreteType()

	if not typeAllowed then
		error(("Failed to load component definition: %s"):format(result))
		return
	end

	local _, default = typeDefinition:tryDefault()

	-- All entities with an
	local entitiesWithComponent = system:all(".anattaInstance", componentName):collect()

	-- Entities that are awaiting destruction (this means their corresponding
	-- instance was deleted or its __entity attribute set to nil). It would be
	-- preferrable to handle entity destruction in another system, but all
	-- attributes must be set in the same undo waypoint (see below).
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

	local addComponent = add(registry, componentName)
	local removeComponent = remove(registry, componentName, pendingComponentValidation)

	system:on(entitiesWithComponent.added, function(entity, instance, component)
		pendingAddition[instance] = nil
		addComponent(entity, instance, component)
	end)

	system:on(entitiesWithComponent.removed, function(entity, instance, component)
		pendingRemoval[instance] = nil
		removeComponent(entity, instance, component)
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

		-- This system is driven by CollectionService added/removed signals. A
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

		-- Destroying an entity first removes all its components (resulting in
		-- the attributes for this component being set to nil), so we must
		-- handle entity destruction here.

		-- TODO: Optimize this by doing a sorted insertion and only checking the
		-- first element of the pool. Adding to the list of destroyed entities
		-- will happen much less frequently than checking it.
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
end
