return function(state, action)
	state = state or ""

	if action.type == "ToggleIconPicker" and not action.component then
		return ""
	end

	if action.type == "SetIconSearch" then
		assert(typeof(action.text) == "string", "Icon search text must be a string")
		return action.text
	end

	return state
end
