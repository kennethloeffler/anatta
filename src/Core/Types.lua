local t = require(script.Parent.Parent.t)

return {
	typeDefinition = t.strictInterface {
		typeName = t.string,
		check = t.callback,
		instanceFields = t.table,
		fields = t.table,
	},

	system = t.strictInterface {
		pure = t.optional(t.boolean),

		components = t.interface {
			required = t.optional(t.array(t.string)),
			forbidden = t.optional(t.array(t.string)),
			updated = t.optional(t.array(t.string)),
		},

		init = t.optional(t.callback),
		onUnload = t.optional(t.callback),

		onAdded = t.optional(t.callback),
		onRemoved = t.optional(t.callback),

		stepped = t.optional(t.callback),
		heartbeat = t.optional(t.callback),
		renderStepped = t.optional(t.callback),
	},
}
