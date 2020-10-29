local t = require(script.Parent.t)

local Interface = {
	interface = true,
	strictInterface = true,
}

local HigherOrder = {
	array = true,
	strictArray = true,
	keys = true,
	values = true,
	map = true,
	set = true,
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
	optional = true,
	tuple = true,
	union = true,
	intersection = true,
	enum = true,
	wrap = true,
	strict = true,
	children = true,
	instanceOf = true,
	instanceIsA = true,
}

local Noop = function() end

local t_TypeDef = t.strictInterface {
	typeName = t.string,
	check = t.callback,
	instanceFields = t.table,
	fields = t.table,
}

local TypeDef = {}

local function checkInterface(typeDef, checkTable)
	for name, fieldTypeDef in pairs(checkTable) do
		local fieldType = fieldTypeDef.typeName

		checkTable[name] = fieldTypeDef.check
		typeDef.fields[name] = fieldTypeDef

		if fieldType == "instance"
			or fieldType == "Instance"
			or fieldType == "instanceOf"
			or fieldType == "instanceIsA"
		then
			typeDef.instanceFields[name] = true
		end
	end

	return t[typeDef.typeName](checkTable)
end

local function getCheck(typeDef, ...)
	local typeName = typeDef.typeName

	if Interface[typeName] then
		return checkInterface(typeDef, ...)
	elseif HigherOrder[typeName] then
		local checks = table.create(select("#", ...))

		for i = 1, select("#", ...) do
			if t_TypeDef(select(i, ...)) then
				checks[i] = select(i, ...).check
			else
				checks[i] = select(i, ...)
			end
		end

		return t[typeName](unpack(checks))
	else
		return t[typeName]
	end
end

local function newTypeDef(typeName, ...)
	local typeDef = {
		typeName = typeName,
		check = Noop,
		instanceFields = {},
		fields = {},
	}

	typeDef.check = getCheck(typeDef, ...)

	return typeDef
end

for typeName in pairs(t) do
	if HigherOrder[typeName] == nil and Interface[typeName] == nil then
		TypeDef[typeName] = newTypeDef(typeName)
	else
		TypeDef[typeName] = function(...)
			return newTypeDef(typeName, ...)
		end
	end
end

return TypeDef
