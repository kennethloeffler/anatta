local jumpAssert = require(script.Parent.jumpAssert)

local ErrConversionFailed = "%s (%s) cannot be turned into an attribute"

local conversions = {
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

function convert(attributeMap, attributeName, concreteType, value)
	if typeof(concreteType) == "table" then
		for field, fieldConcreteType in pairs(concreteType) do
			local fieldAttributeName = ("%s_%s"):format(attributeName, field)

			convert(attributeMap, fieldAttributeName, fieldConcreteType, value[field])
		end
	elseif conversions[concreteType] then
		conversions[concreteType](attributeMap, attributeName, value)
	elseif concreteType ~= nil then
		attributeMap[attributeName] = value
	else
		return false, (ErrConversionFailed:format(attributeName, concreteType))
	end

	return true, attributeMap
end

return function(pool, component)
	jumpAssert(pool.typeCheck(component))

	local concreteType = pool.typeDefinition:tryGetConcreteType()

	jumpAssert(concreteType, ErrConversionFailed:format(pool.name, pool.typeDefinition.typeName))

	return convert({}, pool.name, concreteType, component)
end
