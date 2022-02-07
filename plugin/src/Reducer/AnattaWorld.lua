local Anatta = require(script.Parent.Parent.Parent.Anatta)

local T = Anatta.T

return function(state)
	if state == nil then
		local success, world = pcall(Anatta.createWorld, "AnattaPlugin", {})

		return success and world or Anatta.getWorld("AnattaPlugin")
	end

	return state
end
