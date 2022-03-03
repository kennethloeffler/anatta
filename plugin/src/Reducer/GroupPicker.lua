return function(state, action)
	state = state or nil

	if action.type == "ToggleGroupPicker" then
		return action.component
	end

	return state
end
