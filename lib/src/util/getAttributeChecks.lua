local t = require(script.Parent.Parent.Parent.t)

local generators = {
	enum = function(enum)
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
	end,
}

return function(componentName, typeDefinition)
	local concreteType = typeDefinition:tryGetConcreteType()
	local attributeMap = {}

	if typeof(concreteType) == "table" then
		for field, fieldType in pairs(concreteType) do
			local attributeName = ("%s_%s"):format(componentName, field)

			if typeof(fieldType) == "table" then
				-- We don't support nested tables
				return nil, attributeName, fieldType
			elseif generators[fieldType] then
				attributeMap[attributeName] = generators[fieldType](typeDefinition.typeParams[1][field].typeParams[1])
			else
				attributeMap[attributeName] = typeDefinition.typeParams[1][field].check
			end
		end
	elseif generators[concreteType] then
		attributeMap[componentName] = generators[concreteType](typeDefinition.typeParams[1])
	elseif concreteType ~= nil then
		attributeMap[componentName] = typeDefinition.check
	else
		return nil
	end

	return attributeMap
end
