--[[

	Wrapper around t that lets us inspect detailed type information after the
	fact.

]]

local t = require(script.Parent.Parent.Parent.t)

local isTypeDefinition = t.strictInterface({
	args = t.table,
	check = t.callback,
	typeName = t.string,
})

local firstOrder = {
	boolean = true,
	none = true,
	string = true,
	table = true,
	number = true,
	nan = true,
	integer = true,
	Axes = true,
	BrickColor = true,
	CFrame = true,
	Color3 = true,
	ColorSequence = true,
	ColorSequenceKeypoint = true,
	DockWidgetPluginGuiInfo = true,
	Faces = true,
	Instance = true,
	NumberRange = true,
	NumberSequence = true,
	NumberSequenceKeypoint = true,
	PathWaypoint = true,
	PhysicalProperties = true,
	Random = true,
	Ray = true,
	Rect = true,
	Region3 = true,
	Region3int16 = true,
	TweenInfo = true,
	UDim = true,
	UDim2 = true,
	Vector2 = true,
	Vector3 = true,
	Vector3int16 = true,
	Enum = true,
	EnumItem = true,
	numberPositive = true,
	numberNegative = true,
}

local secondOrder = {
	literal = true,
	keyOf = true,
	valueOf = true,
	integer = true,
	numberMin = true,
	numberMax = true,
	numberMinExclusive = true,
	numberMaxExclusive = true,
	numberConstrained = true,
	numberConstrainedExclusive = true,
	match = true,
	keys = true,
	values = true,
	map = true,
	set = true,
	array = true,
	strictArray = true,
	union = true,
	some = true,
	intersection = true,
	every = true,
	interface = true,
	strictInterface = true,
	instanceOf = true,
	instanceIsA = true,
	enum = true,
	wrap = true,
	strict = true,
}

local concrete = {
	match = "string",
	numberMin = "number",
	numberMax = "number",
	numberMinExclusive = "number",
	numberMaxExclusive = "number",
	numberConstrained = "number",
	numberConstrainedExclusive = "number",
	numberPositive = "number",
	numberNegative = "number",
}

local function unwrap(...)
	local unwrapped = table.create(select("#", ...))

	for i = 1, select("#", ...) do
		local arg = select(i, ...)

		if isTypeDefinition(arg) then
			unwrapped[i] = arg.check
		else
			unwrapped[i] = arg
		end
	end

	return unpack(unwrapped)
end

local Type = {}
Type.__index = Type

function Type._new(typeName, check, ...)
	return setmetatable({
		args = { ... },
		check = check,
		typeName = typeName,
	}, Type)
end

function Type:getConcreteType()
	local concreteType = concrete[self.typeName] or (firstOrder[self.typeName] and self.typeName)

	if concreteType then
		return concreteType
	else
		return nil
	end
end

for typeName in pairs(t) do
	if firstOrder[typeName] ~= nil then
		Type[typeName] = Type._new(typeName, t[typeName])
	elseif secondOrder[typeName] ~= nil then
		Type[typeName] = function(...)
			return Type._new(typeName, t[typeName](unwrap(...)), ...)
		end
	end
end

return Type
