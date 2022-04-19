local Constants = require(script.Parent.Parent.Core.Constants)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local INSTANCE_REF_FOLDER = Constants.InstanceRefFolder

local ErrConversionFailed = "%s (%s) cannot be turned into an attribute"

local function instanceConversion(attributeMap, attributeName, value, instance)
	local refFolder = instance:FindFirstChild(INSTANCE_REF_FOLDER)

	if not refFolder then
		refFolder = Instance.new("Folder")
		refFolder.Name = INSTANCE_REF_FOLDER
		refFolder.Parent = instance
	end

	local objectValue = refFolder:FindFirstChild(attributeName)

	if not objectValue then
		objectValue = Instance.new("ObjectValue")
		objectValue.Name = attributeName
		objectValue.Parent = refFolder
	end

	attributeMap[attributeName] = value
	objectValue.Value = value
end

local conversions = {
	Instance = instanceConversion,
	instanceOf = instanceConversion,
	instance = instanceConversion,
	instanceIsA = instanceConversion,

	enum = function(attributeMap, attributeName, value)
		attributeMap[attributeName] = value.Name
	end,

	TweenInfo = function(attributeMap, attributeName, value)
		convert(attributeMap, attributeName, {
			EasingDirection = "enum",
			Time = "number",
			DelayTime = "number",
			RepeatCount = "number",
			EasingStyle = "enum",
			Reverses = "boolean",
		}, value)
	end,
}

function convert(attributeMap, attributeName, concreteType, instance, entity, value)
	if typeof(concreteType) == "table" then
		for field, fieldConcreteType in pairs(concreteType) do
			local fieldAttributeName = ("%s_%s"):format(attributeName, field)

			convert(attributeMap, fieldAttributeName, fieldConcreteType, instance, entity, value[field])
		end
	elseif conversions[concreteType] then
		conversions[concreteType](attributeMap, attributeName, value, instance)
	elseif concreteType ~= nil then
		attributeMap[attributeName] = value
	else
		return false, (ErrConversionFailed:format(attributeName, concreteType))
	end

	return true, attributeMap
end

return function(instance, entity, definition, component)
	local typeDefinition = definition.type
	local componentName = definition.name
	local checkSuccess, checkResult = typeDefinition.check(component)

	if not checkSuccess then
		return false, ("Error converting %s on %s: %s"):format(componentName, instance:GetFullName(), checkResult)
	end

	local conversionSuccess, concreteType = typeDefinition:tryGetConcreteType()

	if not conversionSuccess then
		return false, ("Error converting %s: %s"):format(componentName, concreteType)
	end

	if typeDefinition.typeName == "array" then
		concreteType = table.create(#component)

		for _ = 1, #component do
			local arrayFieldSuccess, fieldConcreteType = typeDefinition.typeParams[1]:tryGetConcreteType()

			if not arrayFieldSuccess then
				return false, ("Error converting %s: %s"):format(componentName, fieldConcreteType)
			end

			table.insert(concreteType, fieldConcreteType)
		end
	end

	local success, attributeMap = convert({}, componentName, concreteType, instance, entity, component)

	attributeMap[ENTITY_ATTRIBUTE_NAME] = entity

	return success, attributeMap
end
