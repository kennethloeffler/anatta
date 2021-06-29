--[[

	Wrapper around t that lets us inspect detailed type information after the
	fact.

]]

local t = require(script.Parent.Parent.Parent.t)

local isTypeParam = t.strictInterface({
	typeParams = t.table,
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
	enum = "enum",
	integer = "number",
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

local concreters = {
	union = function(typeDefinition)
		local previousConcreteType = typeDefinition.typeParams[1]:tryGetConcreteType()

		for _, typeParam in ipairs(typeDefinition.typeParams) do
			local currentConcreteType = typeParam:tryGetConcreteType()

			if (currentConcreteType == nil) or (currentConcreteType ~= previousConcreteType) then
				return nil
			else
				previousConcreteType = currentConcreteType
			end
		end

		return previousConcreteType
	end,

	literal = function(typeDefinition)
		return typeof(typeDefinition.typeParams[1])
	end,

	strictArray = function(typeDefinition)
		local result = table.create(#typeDefinition.typeParams)

		for i, typeParam in ipairs(typeDefinition.typeParams) do
			result[i] = typeParam:tryGetConcreteType()
		end

		return result
	end,

	strictInterface = function(typeDefinition)
		local result = {}

		for key, def in pairs(typeDefinition.typeParams[1]) do
			result[key] = def:tryGetConcreteType()
		end

		return result
	end,
}

local function unwrap(...)
	local unwrapped = table.create(select("#", ...))

	for i = 1, select("#", ...) do
		local arg = select(i, ...)

		if isTypeParam(arg) then
			unwrapped[i] = arg.check
		elseif typeof(arg) == "table" then
			local tableArg = {}

			for k, v in pairs(arg) do
				tableArg[k] = unwrap(v)
			end

			unwrapped[i] = tableArg
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
		typeParams = { ... },
		check = check,
		typeName = typeName,
	}, Type)
end

function Type:tryGetConcreteType()
	local concreteType = concrete[self.typeName] or (firstOrder[self.typeName] and self.typeName)

	if concreteType then
		return concreteType
	elseif concreters[self.typeName] then
		return concreters[self.typeName](self)
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
