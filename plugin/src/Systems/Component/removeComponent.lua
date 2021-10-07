local CollectionService = game:GetService("CollectionService")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)
local Constants = require(script.Parent.Parent.Parent.Constants)

local PLUGIN_PRIVATE_COMPONENT_PREFIX = Constants.PluginPrivateComponentPrefix
local SECONDS_BEFORE_DESTRUCTION = Constants.SecondsBeforeDestruction

return function(registry, componentName, pendingComponentValidation)
	local typeDefinition = registry:getComponentDefinition(componentName)

	return function(entity, instance, component)
		local wasListening = registry:tryRemoveComponent(entity, ".anattaValidationListener")

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

		if
			not registry:visitComponents(function(visitedComponentName)
				if
					visitedComponentName ~= componentName
					and not visitedComponentName:find(PLUGIN_PRIVATE_COMPONENT_PREFIX)
				then
					return true
				end
			end, entity)
		then
			if instance.Parent ~= nil then
				registry:tryAddComponent(entity, ".anattaScheduledDestruction", tick())
			else
				registry:tryAddComponent(
					entity,
					".anattaScheduledDestruction",
					tick() + SECONDS_BEFORE_DESTRUCTION
				)
			end
		end

		if wasListening then
			registry:addComponent(entity, ".anattaValidationListener")
		end

		registry:tryRemoveComponent(entity, pendingComponentValidation)
	end
end
