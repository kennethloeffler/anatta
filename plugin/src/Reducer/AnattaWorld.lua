local Anatta = require(script.Parent.Parent.Parent.Anatta)

return function(state)
	if state == nil then
		return Anatta:createWorld("AnattaPlugin")
	end

	return state
end
