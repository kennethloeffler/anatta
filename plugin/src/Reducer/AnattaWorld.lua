local Anatta = require(script.Parent.Parent.Parent.Anatta)

local T = Anatta.T

return function(state)
	if state == nil then
		return Anatta:createWorld("AnattaPlugin", {
			{
				name = "AnattaInstance",
				type = T.instance,
			},
		})
	end

	return state
end
