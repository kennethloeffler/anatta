--[=[
	@class T

	`T` is a wrapper around `t` that enables detailed inspection of type information after
	the fact and the ability to construct default values for many kinds of types. [See
	`t`'s documentation for a listing of all the functions present in this
	module.](https://github.com/osyrisrblx/t#crash-course)
]=]

--- @interface TypeDefinition
--- @within T
--- .check (...)
--- .typeParams { TypeDefinition }
--- .typeName string
--- A wrapped `t` check returned by each member function.

local Types = require(script.Parent.Parent.Types)
local t = require(script.Parent.Parent.Parent.t)

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
	instance = "instanceOf",
	instanceOf = "instanceOf",
	instanceIsA = "instanceIsA",
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
		local success, previousConcreteType = typeDefinition.typeParams[1]:tryGetConcreteType()

		if not success then
			return false, previousConcreteType
		end

		for _, typeParam in ipairs(typeDefinition.typeParams) do
			local currentConcreteType
			success, currentConcreteType = typeParam:tryGetConcreteType()

			if not success then
				return false, currentConcreteType
			end

			if (currentConcreteType == nil) or (currentConcreteType ~= previousConcreteType) then
				return false, nil
			else
				previousConcreteType = currentConcreteType
			end
		end

		return true, previousConcreteType
	end,

	literal = function(typeDefinition)
		return true, typeof(typeDefinition.typeParams[1])
	end,

	strictArray = function(typeDefinition)
		local result = table.create(#typeDefinition.typeParams)

		for i, typeParam in ipairs(typeDefinition.typeParams) do
			local success, concreteType = typeParam:tryGetConcreteType()

			if not success then
				return false, concreteType
			end

			result[i] = concreteType
		end

		return true, result
	end,

	strictInterface = function(typeDefinition)
		local result = {}

		for key, def in pairs(typeDefinition.typeParams[1]) do
			local success, concreteType = def:tryGetConcreteType()

			if not success then
				return false, concreteType
			end

			result[key] = concreteType
		end

		return true, result
	end,
}

local concreteFromAbstract = {
	BasePart = "Part",
	Model = "Model",
	Light = "PointLight",
	PVInstance = "Model",
}

local defaults = {
	enum = function(typeDefinition)
		return true, typeDefinition.typeParams[1]:GetEnumItems()[1]
	end,

	table = function(typeDefinition, concreteType)
		local default = {}

		for field in pairs(concreteType) do
			local success, fieldDefault = typeDefinition.typeParams[1][field]:tryDefault()

			if not success then
				return false, fieldDefault
			end

			default[field] = fieldDefault
		end

		return true, default
	end,

	Instance = function()
		return true, Instance.new("Hole")
	end,

	instanceOf = function(typeDefinition)
		return true, Instance.new(typeDefinition.typeParams[1])
	end,

	instance = function(typeDefinition)
		return true, Instance.new(typeDefinition.typeParams[1])
	end,

	instanceIsA = function(typeDefinition)
		local class = typeDefinition.typeParams[1]

		return true, Instance.new(concreteFromAbstract[class] or class)
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
	NumberSequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0),
	}),
	Rect = Rect.new(Vector2.new(), Vector2.new()),
	TweenInfo = TweenInfo.new(),
	UDim = UDim.new(0, 0),
	UDim2 = UDim2.new(0, 0, 0, 0),
	Vector2 = Vector2.new(),
	Vector3 = Vector3.new(),
}

local function unwrap(...)
	local unwrapped = table.create(select("#", ...))

	for i = 1, select("#", ...) do
		local arg = select(i, ...)

		if Types.TypeDefinition(arg) then
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

local TypeDefinition = {}
TypeDefinition.__index = TypeDefinition

function TypeDefinition._new(typeName, check, ...)
	return setmetatable({
		typeParams = { ... },
		check = check,
		typeName = typeName,
	}, TypeDefinition)
end

function TypeDefinition:tryDefault()
	local success, concreteType = self:tryGetConcreteType()
	local value = defaults[concreteType]

	if not success then
		return false, concreteType
	end

	if typeof(concreteType) == "table" then
		return defaults.table(self, concreteType)
	elseif typeof(value) == "function" then
		return value(self, concreteType)
	elseif value ~= nil then
		return true, value
	else
		return false, nil
	end
end

function TypeDefinition:tryGetConcreteType()
	local concreteType = concrete[self.typeName] or (firstOrder[self.typeName] and self.typeName)

	if concreteType then
		return true, concreteType
	elseif concreters[self.typeName] then
		return concreters[self.typeName](self)
	else
		return false, ("%s has no concrete type"):format(self.typeName)
	end
end

for typeName in pairs(t) do
	if firstOrder[typeName] ~= nil then
		TypeDefinition[typeName] = TypeDefinition._new(typeName, t[typeName])
	elseif secondOrder[typeName] ~= nil then
		TypeDefinition[typeName] = function(...)
			return TypeDefinition._new(typeName, t[typeName](unwrap(...)), ...)
		end
	end
end

return TypeDefinition
