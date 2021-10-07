local t = require(script.Parent.Parent.t)

local TypeDefinition = t.strictInterface({
	typeParams = t.table,
	check = t.callback,
	typeName = t.string,
})

--- @interface ComponentDefinition
--- @within Anatta
--- .name string
--- .type TypeDefinition
local ComponentDefinition = t.strictInterface({
	name = t.string,
	type = TypeDefinition,
})

--- @interface Query
--- @within Anatta
--- .withAll {string}?
--- .withUpdated {string}?
--- .withAny {string}?
--- .without {string}?
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
