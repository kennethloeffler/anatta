return function(state, action)
	state = state or {}

	if action.type == "SetUnknownComponents" then
		return action.data
	end

	return state
end
