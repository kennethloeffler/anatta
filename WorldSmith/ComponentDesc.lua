ComponentDesc = {
	[1] = { 
		_metadata = {ComponentType = "PrintToOutput"}, -- stuff anything you want in here - EntityManager doesn't give a damn!
		Enabled = "boolean",
		MsgToPrint = "string"
	},
	[2] = {
		_metadata = {ComponentType = "_trigger"},
		Player = "number"
	},
	[3] = {
		_metadata = {ComponentType = "TouchTrigger"},
		Enabled = "boolean",
		Debounce = "number",
		Delay = "number"
	}
}
return ComponentDesc