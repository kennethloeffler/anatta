return function(state, action)
	state = state or nil

	if action.type == "ToggleColorPicker" then
		return action.component
	end

	return state
end
