return function(state, action)
	state = state or nil

	if action.type == "OpenComponentMenu" then
		return action.component
	end

	return state
end
