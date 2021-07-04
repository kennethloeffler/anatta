local t = require(script.Parent.Parent.Parent.t)

local function getEnumCheck(enum)
	local enums = enum:GetEnumItems()

	for i, enumItem in ipairs(enums) do
		enums[i] = enumItem.Name
	end

	return function(value)
		for _, enumName in ipairs(enums) do
			if enumName == value then
				return true
			end
		end

		return false, ('Expected one of:\n%s;\ngot "%s"'):format(table.concat(enums, "\n"), value)
	end
end

return function(componentName, typeDefinition)
	local concreteType = typeDefinition:tryGetConcreteType()
	local attributeMap = {}

	if typeof(concreteType) == "table" then
		for field, fieldType in pairs(concreteType) do
			local attributeName = ("%s_%s"):format(componentName, field)

			if typeof(fieldType) == "table" then
				-- We don't support nested tables
				return nil, attributeName, fieldType
			end

			if fieldType == "enum" then
				attributeMap[attributeName] = getEnumCheck(typeDefinition.typeParams[1])
			else
				attributeMap[attributeName] = typeDefinition[field].check
			end
		end
	elseif concreteType == "enum" then
		attributeMap[componentName] = getEnumCheck(typeDefinition.typeParams[1])
	elseif concreteType ~= nil then
		attributeMap[componentName] = typeDefinition.check
	else
		return nil
	end

	return attributeMap
end
