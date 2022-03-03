local function setRenaming(component: string, renaming: boolean)
	return {
		type = "SetRenaming",
		component = component,
		renaming = renaming,
	}
end

return setRenaming
