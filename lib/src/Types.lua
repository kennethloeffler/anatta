local t = require(script.Parent.Parent.t)

local TypeDefinition = t.strictInterface({
	typeParams = t.table,
	check = t.callback,
	typeName = t.string,
	_containsRefs = t.boolean,
	_containsEntities = t.boolean,
})

local ComponentDefinition = t.interface({
	description = t.optional(t.string),
	name = t.string,
	type = TypeDefinition,
	pluginType = t.optional(TypeDefinition),
	fromPluginType = t.optional(t.callback),
	canPluginUse = t.optional(t.boolean),
})

local Query = t.strictInterface({
	withAll = t.optional(t.array(ComponentDefinition)),
	withUpdated = t.optional(t.array(ComponentDefinition)),
	withAny = t.optional(t.array(ComponentDefinition)),
	without = t.optional(t.array(ComponentDefinition)),
})

return {
	ComponentDefinition = ComponentDefinition,
	Query = Query,
	TypeDefinition = TypeDefinition,
}
