local defaults = {
	enum = function(typeDefinition)
		return typeDefinition.typeParams[1]:GetEnumItems()[1].Name
	end,
	number = 0,
	string = "",
	boolean = false,
	BrickColor = BrickColor.new(Color3.new()),
	CFrame = CFrame.new(),
	Color3 = Color3.new(),
	CoorSequence = ColorSequence.new({
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

return function(concreteType, typeDefinition)
	local value = defaults[concreteType]

	if typeof(value) == "function" then
		return value(typeDefinition)
	elseif value ~= nil then
		return value
	else
		-- Attributes don't support this type
		return nil
	end
end
