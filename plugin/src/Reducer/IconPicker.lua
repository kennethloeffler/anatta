return function(state, action)
	state = state or nil

	if action.type == "ToggleIconPicker" then
		return action.component
	end

	return state
end
