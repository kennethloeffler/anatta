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

	Query = t.strictInterface({
		without = t.optional(t.array(t.string)),
		withAny = t.optional(t.array(t.string)),
		withAll = t.optional(t.array(t.string)),
		withUpdated = t.optional(t.array(t.string)),
	}),

	TypeDefinition = TypeDefinition,
}
