local Modules = script.Parent.Parent.Parent

local Dom = require(Modules.Anatta.Library.Dom)
local Constants = require(Modules.Anatta.Library.Core.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local INSTANCE_REF_FOLDER = Constants.InstanceRefFolder

local ComponentAnnotation = {}

function ComponentAnnotation.getDefaultAttributeMap(instance, definition)
	local defaultSuccess, default = definition.type:tryDefault()

	if not defaultSuccess and not definition.type.typeName == "none" then
		return false, default
	end

	local attributeSuccess, attributeMap = Dom.tryToAttributes(instance, 0, definition, default)

	return attributeSuccess, attributeMap, default
end

function ComponentAnnotation.apply(instance, definition, value)
	if definition.pluginType then
		definition = { name = definition.name, type = definition.pluginType }
	end

	local success, attributeMap
	local usingDefault = false

	if value == nil then
		success, attributeMap = ComponentAnnotation.getDefaultAttributeMap(instance, definition)
		usingDefault = true

		if not success then
			return false, attributeMap
		end
	else
		success, attributeMap = Dom.tryToAttributes(instance, 0, definition, value)

		if not success then
			return false, attributeMap
		end
	end

	for attributeName, attributeValue in pairs(attributeMap) do
		if typeof(attributeValue) == "Instance" then
			if usingDefault or attributeValue.Parent == nil then
				attributeValue.Parent = workspace.Terrain
				attributeValue.Archivable = false
			end

			instance[INSTANCE_REF_FOLDER][attributeName].Value = attributeValue
		elseif attributeName ~= ENTITY_ATTRIBUTE_NAME then
			instance:SetAttribute(attributeName, attributeValue)
		end
	end

	return true
end

function ComponentAnnotation.remove(instance, definition)
	if definition.pluginType then
		definition = { name = definition.name, type = definition.pluginType }
	end

	local _, _, component = Dom.tryFromAttributes(instance, definition)
	local success, attributeMap = Dom.tryToAttributes(instance, 0, definition, component)

	if not success then
		return false, attributeMap
	end

	for attributeName, attributeValue in pairs(attributeMap) do
		if typeof(attributeValue) == "Instance" then
			local anattaRefs = instance:FindFirstChild(INSTANCE_REF_FOLDER)

			if anattaRefs then
				local objectValue = anattaRefs:FindFirstChild(attributeName)

				if objectValue then
					objectValue.Parent = nil
				end

				if not next(anattaRefs:GetChildren()) then
					anattaRefs.Parent = nil
				end
			end
		elseif attributeName ~= ENTITY_ATTRIBUTE_NAME then
			instance:SetAttribute(attributeName, nil)
		end
	end

	return true
end

return ComponentAnnotation
