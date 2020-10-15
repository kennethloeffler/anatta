local t = require(script.Parent.t)

local TypeDef = {}

local noop = function() end

local interface = {
	interface = true,
	strictInterface = true,
}

local higherOrder = {
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

local typeDefType = t.strictInterface {
	type = t.string,
	check = t.callback,
	instanceFields = t.table,
	fields = t.table,
}

local function checkInterface(typeDef, checkTable)
	for name, fieldTypeDef in pairs(checkTable) do
		local fieldType = fieldTypeDef.type

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

	return t[typeDef.type](checkTable)
end

local function getCheck(typeDef, ...)
	local type = typeDef.type

	if interface[type] then
		return checkInterface(typeDef, ...)
	elseif higherOrder[type] then
		local checks = table.create(select("#", ...))

		for i = 1, select("#", ...) do
			if typeDefType(select(i, ...)) then
				checks[i] = select(i, ...).check
			else
				checks[i] = select(i, ...)
			end
		end

		return t[type](unpack(checks))
	else
		return t[type]
	end
end

local function newTypeDef(type, ...)
	local typeDef = {
		type = type,
		check = noop,
		instanceFields = {},
		fields = {},
	}

	typeDef.check = getCheck(typeDef, ...)

	return typeDef
end

for type in pairs(t) do
	if higherOrder[type] == nil and interface[type] == nil then
		TypeDef[type] = newTypeDef(type)
	else
		TypeDef[type] = function(...)
			return newTypeDef(type, ...)
		end
	end
end

return TypeDef
