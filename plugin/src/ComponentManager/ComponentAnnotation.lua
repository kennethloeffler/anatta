local CollectionService = game:GetService("CollectionService")

local Modules = script.Parent.Parent.Parent

local Dom = require(Modules.Anatta.Library.Dom)
local Constants = require(Modules.Anatta.Library.Core.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName

local ComponentAnnotation = {}

local function getAttributeMap(instance, definition)
	local defaultSuccess, default = definition.type:tryDefault()

	if not defaultSuccess and not definition.type.typeName == "none" then
		return false, default
	end

	local attributeSuccess, attributeMap = Dom.tryToAttributes(instance, 0, definition, default)

	return attributeSuccess, attributeMap, default
end

function ComponentAnnotation.add(instance, definition)
	local success, attributeMap = getAttributeMap(instance, definition)

	if not success then
		return false, attributeMap
	end

	for attributeName, attributeValue in pairs(attributeMap) do
		if typeof(attributeValue) == "Instance" then
			instance.__anattaRefs[attributeName].Value = attributeValue
		elseif attributeName ~= ENTITY_ATTRIBUTE_NAME then
			instance:SetAttribute(attributeName, attributeValue)
		end
	end

	CollectionService:AddTag(instance, definition.name)

	return true
end

function ComponentAnnotation.remove(instance, definition)
	local success, attributeMap = getAttributeMap(instance, definition)

	if not success then
		return false, attributeMap
	end

	for attributeName, attributeValue in pairs(attributeMap) do
		if typeof(attributeValue) == "Instance" then
			local anattaRefs = instance:FindFirstChild("__anattaRefs")

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

	CollectionService:RemoveTag(instance, definition.name)

	return true
end

return ComponentAnnotation
