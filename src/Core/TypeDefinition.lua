local Types = require(script.Parent.Types)
local t = require(script.Parent.Parent.t)

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

local TypeDefinition = {}

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
		elseif fieldType == "RBXScriptConnection" then
			typeDef.connectionFields[name] = true
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
			if Types.typeDefinition(select(i, ...)) then
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

local function newTypeDefinition(typeName, ...)
	local typeDef = {
		typeName = typeName,
		check = Noop,
		instanceFields = {},
		connectionFields = {},
		fields = {},
	}

	typeDef.check = getCheck(typeDef, ...)

	return typeDef
end

for typeName in pairs(t) do
	if HigherOrder[typeName] == nil and Interface[typeName] == nil then
		TypeDefinition[typeName] = newTypeDefinition(typeName)
	else
		TypeDefinition[typeName] = function(...)
			return newTypeDefinition(typeName, ...)
		end
	end
end

return TypeDefinition
