local t = require(script.Parent.Parent.t)

return {
	pureSystem = t.strictInterface {
		isPure = t.literal(true),

		definitions = t.optional(t.map(t.string, t.callback)),

		collection = t.strictInterface {
			required = t.optional(t.array(t.string)),
			forbidden = t.optional(t.array(t.string)),
		},

		onLoaded = t.optional(t.callback),
		onUnloaded = t.optional(t.callback),

		onAdded = t.optional(t.callback),
		onRemoved = t.optional(t.callback),
	},
	system = t.strictInterface {
		definitions = t.map(t.string, t.callback),

		collection = t.strictInterface {
			required = t.optional(t.array(t.string)),
			forbidden = t.optional(t.array(t.string)),
			updated = t.optional(t.array(t.string)),
		},

		onLoaded = t.optional(t.callback),
		onUnloaded = t.optional(t.callback),

		onAdded = t.optional(t.callback),
		onRemoved = t.optional(t.callback),
	},
}
