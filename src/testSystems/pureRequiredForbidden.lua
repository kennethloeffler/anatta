return {
	components = {
		required = { "Test1", "Test2" },
		forbidden = { "Test3" },
	},

	init = function(map)
		map:each(function()
			return {}, {}
		end)
	end,
}
