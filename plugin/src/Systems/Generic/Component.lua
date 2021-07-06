local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Anatta = require(script:FindFirstAncestor("AnattaPlugin").Anatta)
local Constants = require(script.Parent.Parent.Parent.Constants)
local util = require(script.Parent.Parent.util)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local PLUGIN_PRIVATE_COMPONENT_PREFIX = Constants.PluginPrivateComponentPrefix

return function(system, registry, componentName)
	local pendingAddition = {}
	local pendingRemoval = {}

	local typeDefinition = registry:getDefinition(componentName)
	local default = typeDefinition:default()
	local success, attributeMap = Anatta.Dom.tryToAttribute(default, componentName, typeDefinition)

	if not success then
		warn(attributeMap)
		return
	end

	system:on(CollectionService:GetInstanceAddedSignal(componentName), function(instance)
		pendingAddition[instance] = true
		pendingRemoval[instance] = nil
	end)

	system:on(CollectionService:GetInstanceRemovedSignal(componentName), function(instance)
		pendingAddition[instance] = nil
		pendingRemoval[instance] = true
	end)

	system:on(RunService.Heartbeat, function()
		for instance in pairs(pendingRemoval) do
			local entity = util.getValidEntity(registry, instance)

			pendingRemoval[instance] = nil
			registry:tryRemove(entity, componentName)
			registry:tryRemove(entity, "__anattaPluginValidationListener")

			for attributeName in pairs(attributeMap) do
				instance:SetAttribute(attributeName, nil)
			end

			if
				registry:visit(function(visitedComponentName)
					if not visitedComponentName:find(PLUGIN_PRIVATE_COMPONENT_PREFIX) then
						return true
					end
				end, entity) == nil
			then
				registry:destroy(entity)
				instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, nil)
			else
				registry:add(entity, "__anattaPluginValidationListener")
			end
		end

		for instance in pairs(pendingAddition) do
			local entity = util.getValidEntity(registry, instance)

			pendingAddition[instance] = nil
			registry:add(entity, componentName, default)
			registry:tryRemove(entity, "__anattaPluginValidationListener")

			for attributeName, defaultValue in pairs(attributeMap) do
				instance:SetAttribute(attributeName, defaultValue)
			end

			registry:add(entity, "__anattaPluginValidationListener")
		end
	end)
end
