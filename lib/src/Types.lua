local t = require(script.Parent.Parent.t)

local TypeDefinition = t.strictInterface({
	typeParams = t.table,
	check = t.callback,
	typeName = t.string,
})

local ComponentDefinition = t.strictInterface({
	description = t.optional(t.string),
	name = t.string,
	type = TypeDefinition,
})

local Query = t.strictInterface({
	withAll = t.optional(t.array(t.string)),
	withUpdated = t.optional(t.array(t.string)),
	withAny = t.optional(t.array(t.string)),
	without = t.optional(t.array(t.string)),
})

return {
	ComponentDefinition = ComponentDefinition,
	Query = Query,
	TypeDefinition = TypeDefinition,
}
