local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Core.Constants)
local util = require(script.Parent.Parent.util)

local tryFromAttributes = require(script.Parent.tryFromAttributes)
local tryToAttributes = require(script.Parent.tryToAttributes)

local INSTANCE_REF_FOLDER = Constants.InstanceRefFolder

local function shouldIgnore(instance, ancestorsToIgnore)
	for _, ancestor in ipairs(ancestorsToIgnore) do
		if instance:IsDescendantOf(ancestor) then
			return true
		end
	end

	return false
end

return function(pool, ancestorsToIgnore)
	util.jumpAssert(pool.size == 0, "Pool must be empty")
	local definition
	local componentDefinition = pool.componentDefinition

	if componentDefinition.pluginType ~= nil then
		definition = { name = componentDefinition.name, type = componentDefinition.pluginType }
	else
		definition = componentDefinition
	end

	local tagged = CollectionService:GetTagged(definition.name)
	local taggedCount = #tagged

	pool.dense = table.create(taggedCount)
	pool.components = table.create(taggedCount)

	for _, instance in ipairs(tagged) do
		local ignore = shouldIgnore(instance, ancestorsToIgnore)
		local success, entity, rawComponent = tryFromAttributes(instance, definition)

		if not success then
			warn(("%s failed attribute validation for %s: %s"):format(instance:GetFullName(), definition.name, entity))
			continue
		end

		if componentDefinition.pluginType ~= nil then
			local _, pluginAttributeMap = tryToAttributes(instance, entity, definition, rawComponent)
			local component = componentDefinition.fromPluginType
				and componentDefinition.fromPluginType(instance, rawComponent)

			for attributeName, value in pairs(pluginAttributeMap) do
				if typeof(value) == "Instance" then
					instance[INSTANCE_REF_FOLDER][attributeName]:Destroy()
				else
					instance:SetAttribute(attributeName, nil)
				end
			end

			local conversionSuccess, attributeMap = tryToAttributes(instance, entity, componentDefinition, component)

			if not conversionSuccess then
				warn(("%s failed conversion from plugin type for %s"):format(instance:GetFullName(), definition.name))
				continue
			end

			for attributeName, value in pairs(attributeMap) do
				if typeof(value) == "Instance" then
					instance[INSTANCE_REF_FOLDER][attributeName].Value = value
				else
					instance:SetAttribute(attributeName, value)
				end
			end

			if not ignore then
				pool:insert(entity, component)
			end
		elseif not ignore then
			pool:insert(entity, rawComponent)
		end
	end

	return true, pool
end
