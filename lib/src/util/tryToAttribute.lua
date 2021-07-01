local getAttributeDefault = require(script.Parent.getAttributeDefault)

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

			local defaultValue = getAttributeDefault(fieldType, typeDefinition.typeParams[1][field])

			if defaultValue ~= nil then
				attributeMap[attributeName] = defaultValue
			else
				-- Attributes don't support this type
				return nil, attributeName, fieldType
			end
		end
	elseif concreteType ~= nil then
		local defaultValue = getAttributeDefault(concreteType, typeDefinition)

		if defaultValue ~= nil then
			attributeMap[componentName] = defaultValue
		else
			return nil, componentName, concreteType
		end
	else
		return nil
	end

	return attributeMap
end
