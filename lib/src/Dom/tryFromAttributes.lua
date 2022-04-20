local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Parent.Core.Constants)
local T = require(script.Parent.Parent.Core.T)

local ENTITY_ATTRIBUTE_NAME = Constants.EntityAttributeName
local INSTANCE_REF_FOLDER = Constants.InstanceRefFolder

local ErrMissingEntityAttribute = "%s is missing an entity attribute"

local TweenInfoType = T.strictInterface({
	Time = T.number,
	EasingStyle = T.enum(Enum.EasingStyle),
	EasingDirection = T.enum(Enum.EasingDirection),
	RepeatCount = T.number,
	Reverses = T.boolean,
	DelayTime = T.number,
})

local function instanceConversion(instance, entity, attributeName, typeDefinition)
	local refFolder = instance:FindFirstChild(INSTANCE_REF_FOLDER)

	if not refFolder or not refFolder:IsA("Folder") then
		return false,
			("Expected ref folder as a child of %s, got %s"):format(instance:GetFullName(), tostring(refFolder))
	end

	local objectValue = refFolder:FindFirstChild(attributeName)

	if not objectValue or not objectValue:IsA("ObjectValue") then
		return false,
			("Expected ObjectValue %s under %s, got %s"):format(
				attributeName,
				instance:GetFullName(),
				tostring(objectValue)
			)
	end

	local ref = objectValue.Value
	local success, result = typeDefinition.check(ref)

	if success then
		return true, entity, ref
	else
		return false, result
	end
end

local conversions = {
	Instance = instanceConversion,
	instanceOf = instanceConversion,
	instance = instanceConversion,
	instanceIsA = instanceConversion,

	none = function(instance, entity, attributeName)
		return CollectionService:HasTag(instance, attributeName), entity, nil
	end,

	enum = function(instance, entity, attributeName, typeDefinition)
		local enum = typeDefinition.typeParams[1]
		local enums = enum:GetEnumItems()
		local enumName = instance:GetAttribute(attributeName)

		if enumName == nil then
			return false, ("%s expected, got nil"):format(tostring(enum))
		end

		for i, enumItem in ipairs(enums) do
			enums[i] = enumItem.Name
		end

		for _, name in ipairs(enums) do
			if name == enumName then
				return true, entity, enum[enumName]
			end
		end

		return false, ('Expected one of:\n\n\t\t%s;\n\n\tgot "%s"'):format(table.concat(enums, "\n\t\t"), enumName)
	end,

	TweenInfo = function(instance, entity, attributeName)
		local success, result = convert(instance, attributeName, TweenInfoType)

		if success then
			return true,
				entity,
				TweenInfo.new(
					result.Time,
					result.EasingStyle,
					result.EasingDirection,
					result.RepeatCount,
					result.Reverses,
					result.DelayTime
				)
		else
			return false, result
		end
	end,
}

function convert(instance, attributeName, typeDefinition)
	local success, concreteType = typeDefinition:tryGetConcreteType()

	if not success then
		return false, concreteType
	end

	local entity = instance:GetAttribute(ENTITY_ATTRIBUTE_NAME)

	if entity == nil or typeof(entity) ~= "number" then
		return false, ErrMissingEntityAttribute:format(instance:GetFullName())
	end

	if typeof(concreteType) == "table" then
		local value = {}
		local typeParams

		if typeDefinition.typeName == "strictArray" or typeDefinition.typeName == "array" then
			typeParams = typeDefinition.typeParams
		else
			typeParams = typeDefinition.typeParams[1]
		end

		if typeDefinition.typeName ~= "array" then
			for field in pairs(concreteType) do
				local fieldAttributeName = ("%s_%s"):format(attributeName, field)
				local fieldTypeDefinition = typeParams[field]
				local convertSuccess, result, componentValue = convert(
					instance,
					fieldAttributeName,
					fieldTypeDefinition
				)

				if convertSuccess then
					value[field] = componentValue
				else
					return false, result
				end
			end
		else
			local index = 1
			local fieldAttributeName = ("%s_%s"):format(attributeName, index)
			local fieldTypeDefinition = typeParams[1]
			local convertSuccess, _, componentValue = convert(instance, fieldAttributeName, fieldTypeDefinition)
			while convertSuccess do
				table.insert(value, componentValue)

				index += 1
				fieldAttributeName = ("%s_%s"):format(attributeName, index)
				convertSuccess, _, componentValue = convert(instance, fieldAttributeName, fieldTypeDefinition)
			end

			return true, entity, value
		end

		return true, entity, value
	elseif conversions[concreteType] then
		return conversions[concreteType](instance, entity, attributeName, typeDefinition)
	else
		local value = instance:GetAttribute(attributeName)
		local err
		success, err = typeDefinition.check(value)

		if success then
			return true, entity, value
		else
			return false, err
		end
	end
end

return function(instance, componentDefinition)
	return convert(instance, componentDefinition.name, componentDefinition.type)
end
