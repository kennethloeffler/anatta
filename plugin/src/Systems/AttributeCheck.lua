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
	local validateCollection = system:all("__anattaInstance", "__anattaValidate"):collect()

	validateCollection:attach(function(entity, instance)
		return {
			instance.AttributeChanged:Connect(function(attributeName)
				local currentValue = instance:GetAttribute(attributeName)

				if attributeName == ENTITY_ATTRIBUTE_NAME and currentValue ~= entity then
					instance:SetAttribute(ENTITY_ATTRIBUTE_NAME, entity)
				elseif currentValue == nil then
					return
				else
					local componentName = registry:visit(function(name)
						if name:find(PRIVATE_COMPONENT_PREFIX) then
							return nil
						elseif attributeName:find(name) then
							return name
						end
					end, entity)

					if not componentName then
						return
					end

					local pool = registry:getPool(componentName)
					local success, result = util.tryFromAttribute(pool, instance)

					if not success then
						local previousValue = registry:get(entity, componentName)
						-- tryToAttribute will always succeed here because the previous
						-- value is definitely valid.
						local _, attributeMap = util.tryToAttribute(pool, previousValue)

						for name, value in pairs(attributeMap) do
							instance:SetAttribute(name, value)
						end

						if result then
							warn(result)
						end
					else
						registry:replace(entity, componentName, result)
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
