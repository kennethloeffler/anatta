local Llama = require(script.Parent.Parent.Parent.Llama)

return function(state, action)
	state = state or {}

	if action.type == "OpenComponentMenu" then
		local value = if action.isMenuOpen then action.component else Llama.None
		state = Llama.Dictionary.merge(state, { [action.component.Name] = value })
	end

	return state
end
