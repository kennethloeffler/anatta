local Anatta = require(script.Parent.Parent.Anatta)

local Systems = script.Parent.Systems

return function(plugin)
	local anatta = Anatta.new({})

	anatta:loadSystems(Systems)

	plugin:beforeUnload(function()
		anatta:unloadSystems(Systems)
	end)
end
