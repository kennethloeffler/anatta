return function(state, action)
	state = state or {}

	local filtered = {}

	for _, component in pairs(action.data) do
		if component.Definition:tryGetConcreteType() then
			table.insert(filtered, component)
		end
	end

	if action.type == "SetComponentData" then
		return action.data
	end

	return state
end
