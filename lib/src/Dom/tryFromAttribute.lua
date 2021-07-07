local function convertEnum(instance, attributeName, typeDefinition, enum)
	enum = enum or typeDefinition.typeParams[1]
	local enums = enum:GetEnumItems()
	local enumName = instance:GetAttribute(attributeName)

	if enumName == nil then
		return false
	end

	for i, enumItem in ipairs(enums) do
		enums[i] = enumItem.Name
	end

	for _, name in ipairs(enums) do
		if name == enumName then
			return true, enum[enumName]
		end
	end

	return false, ('Expected one of:\n\n\t\t%s;\n\n\tgot "%s"'):format(
		table.concat(enums, "\n\t\t"),
		enumName
	)
end

local conversions = {
	enum = convertEnum,

	TweenInfo = function(instance, attributeName)
		local easingStyleSuccess, easingStyle = convertEnum(
			instance,
			attributeName .. "_EasingStyle",
			nil,
			Enum.EasingStyle
		)
		local easingDirectionSuccess, easingDirection = convertEnum(
			instance,
			attributeName .. "_EasingDirection",
			nil,
			Enum.EasingDirection
		)

		if not easingStyleSuccess then
			return false, easingStyle
		end

		if not easingDirectionSuccess then
			return false, easingDirection
		end

		return true, TweenInfo.new(
			instance:GetAttribute(attributeName .. "_Time"),
			easingStyle,
			easingDirection,
			instance:GetAttribute(attributeName .. "_RepeatCount"),
			instance:GetAttribute(attributeName .. "_Reverses"),
			instance:GetAttribute(attributeName .. "_DelayTime")
		)
	end,
}

function convert(instance, attributeName, typeDefinition)
	local concreteType = typeDefinition:tryGetConcreteType()

	if typeof(concreteType) == "table" then
		local value = {}

		for field in pairs(concreteType) do
			local fieldAttributeName = ("%s_%s"):format(attributeName, field)
			local fieldTypeDefinition = typeDefinition.typeParams[1][field]
			local success, result = convert(instance, fieldAttributeName, fieldTypeDefinition)

			if success then
				value[field] = result
			else
				return false, result
			end
		end

		return true, value
	elseif conversions[concreteType] then
		return conversions[concreteType](instance, attributeName, typeDefinition)
	elseif concreteType ~= nil then
		local value = instance:GetAttribute(attributeName)
		local success, err = typeDefinition.check(value)

		if success then
			return true, value
		else
			return false, err
		end
	else
		return false, ("%s (%s) has no concrete type"):format(attributeName, typeDefinition.typeName)
	end
end

return convert
