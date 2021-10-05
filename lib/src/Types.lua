local t = require(script.Parent.Parent.t)

local TypeDefinition = t.strictInterface({
	typeParams = t.table,
	check = t.callback,
	typeName = t.string,
})

return {
	ComponentDefinition = t.strictInterface({
		name = t.string,
		type = TypeDefinition,
	}),

	TypeDefinition = TypeDefinition,
}
