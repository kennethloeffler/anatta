local t = require(script.Parent.Parent.Core.Type)

local TweenInfoType = t.strictInterface({
	Time = t.number,
	EasingStyle = t.enum(Enum.EasingStyle),
	EasingDirection = t.enum(Enum.EasingDirection),
	RepeatCount = t.number,
	Reverses = t.boolean,
	DelayTime = t.number,
})

local conversions = {
	enum = function(instance, attributeName, typeDefinition)
		local enum = typeDefinition.typeParams[1]
		local enums = enum:GetEnumItems()
		local enumName = instance:GetAttribute(attributeName)

		if enumName == nil then
			return false, ("Got nil for %s"):format(tostring(enum))
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
	end,

	TweenInfo = function(instance, attributeName)
		local success, result = convert(instance, attributeName, TweenInfoType)

		if success then
			return true, TweenInfo.new(
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
