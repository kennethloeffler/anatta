local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")

local Constants = require(script.Parent.Parent.Constants)
local util = require(script.Parent.Parent.Parent.Anatta.Library.util)

local getValidEntity = require(script.Parent.Parent.getValidEntity)

local PRIVATE_COMPONENT_PREFIX = Constants.PrivateComponentPrefix
local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

local AttributeCheck = {}

function AttributeCheck:init()
	local registry = self.registry
	local system = self.system

	local previousSelection = {}
	local dirty = false
	local validateCollection = system:all("__anattaAssociatedInstance", "__anattaValidate"):collect()

	validateCollection:attach(function(entity, instance)
		local componentTypes = {}
		local attributeMap = {}

		registry:visit(function(componentName)
			if componentName:find(PRIVATE_COMPONENT_PREFIX) then
				return
			end

			local typeDefinition = registry:getPools(componentName)[1].typeDefinition

			componentTypes[componentName] = typeDefinition
			attributeMap[componentName] = util.tryFromAttribute(instance, componentName, typeDefinition)
		end, entity)

		return {
			instance.AttributeChanged:Connect(function(attributeName)
				if
					attributeName == ENTITY_ATTRIBUTE_NAME
					and instance:GetAttribute(ENTITY_ATTRIBUTE_NAME) ~= entity
				then
					instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, entity)
				else
					for componentName, typeDefinition in pairs(componentTypes) do
						if not attributeName:find(componentName) then
							continue
						end

						local checks = util.getAttributeChecks(componentName, typeDefinition)
						local previousValue = attributeMap[componentName][attributeName]
						local newValue = instance:GetAttribute(attributeName)
						local success, err = checks[attributeName](newValue)

						if not success then
							warn(err)
							instance:SetAttribute(attributeName, previousValue)
						else
							attributeMap[componentName][attributeName] = newValue
						end
					end
				end
			end),
		}
	end)

	system:on(Selection.SelectionChanged, function()
		dirty = true
	end)

	system:on(RunService.Heartbeat, function()
		if not dirty then
			return
		end

		dirty = false

		local selection = Selection:Get()

		for _, instance in ipairs(selection) do
			if instance:GetAttribute(ENTITY_ATTRIBUTE_NAME) == nil then
				continue
			end

			local entity = getValidEntity(registry, instance)
			previousSelection[instance] = nil
			registry:tryAdd(entity, "__anattaValidate")
		end

		for instance in pairs(previousSelection) do
			if instance:GetAttribute(ENTITY_ATTRIBUTE_NAME) == nil then
				continue
			end

			registry:tryRemove(getValidEntity(registry, instance), "__anattaValidate")
			previousSelection[instance] = nil
		end

		for _, instance in ipairs(selection) do
			previousSelection[instance] = true
		end
	end)
end

return AttributeCheck
