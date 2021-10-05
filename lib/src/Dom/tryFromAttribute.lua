local Constants = require(script.Parent.Parent.Core.Constants)
local t = require(script.Parent.Parent.Core.TypeDefinition)

local INSTANCE_REF_FOLDER = Constants.InstanceRefFolder

local TweenInfoType = t.strictInterface({
	Time = t.number,
	EasingStyle = t.enum(Enum.EasingStyle),
	EasingDirection = t.enum(Enum.EasingDirection),
	RepeatCount = t.number,
	Reverses = t.boolean,
	DelayTime = t.number,
})

local function instanceConversion(instance, attributeName, typeDefinition)
	local refFolder = instance:FindFirstChild(INSTANCE_REF_FOLDER)

	if not refFolder or not refFolder:IsA("Folder") then
		return false, ("Expected ref folder under %s, got %s"):format(
			instance:GetFullName(),
			tostring(refFolder)
		)
	end

	local objectValue = refFolder:FindFirstChild(attributeName)

	if not objectValue or not objectValue:IsA("ObjectValue") then
		return false, ("Expected ObjectValue %s under %s, got %s"):format(
			attributeName,
			instance:GetFullName(),
			tostring(objectValue)
		)
	end

	local ref = objectValue.Value
	local success, result = typeDefinition.check(ref)

	if success then
		return true, ref
	else
		return false, result
	end
end

local conversions = {
	Instance = instanceConversion,
	instanceOf = instanceConversion,
	instance = instanceConversion,
	instanceIsA = instanceConversion,

	enum = function(instance, attributeName, typeDefinition)
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
	local success, concreteType = typeDefinition:tryGetConcreteType()

	if not success then
		return false, ("Error converting %s: %s"):format(attributeName, concreteType)
	end

	if typeof(concreteType) == "table" then
		local value = {}

		for field in pairs(concreteType) do
			local fieldAttributeName = ("%s_%s"):format(attributeName, field)
			local fieldTypeDefinition = typeDefinition.typeParams[1][field]
			local result
			success, result = convert(instance, fieldAttributeName, fieldTypeDefinition)

			if success then
				value[field] = result
			else
				return false, result
			end
		end

		return true, value
	elseif conversions[concreteType] then
		return conversions[concreteType](instance, attributeName, typeDefinition)
	else
		local value = instance:GetAttribute(attributeName)
		local err
		success, err = typeDefinition.check(value)

		if success then
			return true, value
		else
			return false, err
		end
	end
end

return convert
