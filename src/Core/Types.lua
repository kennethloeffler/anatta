local t = require(script.Parent.Parent.t)

return {
	pureSystem = t.interface {
		isPure = t.literal(true),

		collection = t.strictInterface {
			required = t.optional(t.array(t.string)),
			forbidden = t.optional(t.array(t.string)),
			optional = t.optional(t.array(t.string)),
		},

		onLoaded = t.optional(t.callback),
		onUnloaded = t.optional(t.callback),

		onAdded = t.optional(t.callback),
		onRemoved = t.optional(t.callback),
	},
	system = t.interface {
		collection = t.strictInterface {
			required = t.optional(t.array(t.string)),
			forbidden = t.optional(t.array(t.string)),
			updated = t.optional(t.array(t.string)),
			optional = t.optional(t.array(t.string)),
		},

		onLoaded = t.optional(t.callback),
		onUnloaded = t.optional(t.callback),

		onAdded = t.optional(t.callback),
		onRemoved = t.optional(t.callback),
	},
}
