return {
	components = {
		required = { "Test1", "Test2" },
		forbidden = { "Test3" },
	},

	init = function(reducer)
		reducer:each(function()
			return {}, {}
		end)
	end,
}
