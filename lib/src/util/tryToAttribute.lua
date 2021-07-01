local defaultValues = {
	enum = function(typeDefinition)
		return typeDefinition.typeParams[1]:GetEnumItems()[1].Name
	end,
	number = 0,
	string = "",
	boolean = false,
	BrickColor = BrickColor.new(Color3.new()),
	CFrame = CFrame.new(),
	Color3 = Color3.new(),
	ColorSequence = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new()),
		ColorSequenceKeypoint.new(1, Color3.new()),
	}),
	NumberRange = NumberRange.new(0, 0),
	NumberSequence = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) }),
	Rect = Rect.new(Vector2.new(), Vector2.new()),
	UDim = UDim.new(0, 0),
	UDim2 = UDim2.new(0, 0, 0, 0),
	Vector2 = Vector2.new(),
	Vector3 = Vector3.new(),
}

return function(componentName, typeDefinition)
	local concreteType = typeDefinition:tryGetConcreteType()
	local attributeMap = {}

	if concreteType ~= nil then
		if typeof(concreteType) == "table" then
			for field, fieldType in pairs(concreteType) do
				local attributeName = ("%s_%s"):format(componentName, field)

				if typeof(fieldType) == "table" then
					-- We don't support nested tables
					return nil, attributeName, fieldType
				end

				local value = defaultValues[fieldType]

				if typeof(value) == "function" then
					attributeMap[attributeName] = value(typeDefinition.typeParams[1][field])
				elseif value ~= nil then
					attributeMap[attributeName] = value
				else
					-- Attributes don't support this type
					return nil, attributeName, fieldType
				end
			end
		else
			local value = defaultValues[concreteType]

			if typeof(value) == "function" then
				attributeMap[componentName] = value(typeDefinition)
			elseif value ~= nil then
				attributeMap[componentName] = value
			else
				return nil, componentName, concreteType
			end
		end
	else
		return nil
	end

	return attributeMap
end
