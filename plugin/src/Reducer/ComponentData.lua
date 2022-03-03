return function(state, action)
	state = state or {}

	if action.type == "SetComponentData" then
		return action.data
	end

	return state
end
