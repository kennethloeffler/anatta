local Registry = require(script.Parent.Parent.Entity.Registry)
local Selector = require(script.Parent.Parent.Entity.Selector)

return {
	components = {
		required = { "Test1" },
		forbidden = { "Test2" },
	},

	onAdded = function(registry, selector)
		assert(getmetatable(registry) == Registry)
		assert(getmetatable(selector) == Selector)

		return function()
		end
	end,

	onRemoved = function(registry, selector)
		assert(getmetatable(registry) == Registry)
		assert(getmetatable(selector) == Selector)

		return function()
		end
	end,

	heartbeat = function(registry, selector)
		assert(getmetatable(registry) == Registry)
		assert(getmetatable(selector) == Selector)

		return function()
		end
	end,

	stepped = function(registry, selector)
		assert(getmetatable(registry) == Registry)
		assert(getmetatable(selector) == Selector)

		return function()
		end
	end,
}
