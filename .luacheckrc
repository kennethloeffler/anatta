stds.roblox = {
	globals = {
		"game"
	},
	read_globals = {
		-- Roblox globals
		"script", "plugin",

		-- Extra functions
		"tick", "warn", "spawn",
		"wait", "settings", "typeof",
		"bit32",

		-- Types
		"Vector2", "Vector3",
		"Vector2int16",
		"Color3",
		"UDim", "UDim2",
		"Rect",
		"CFrame",
		"Enum",
		"Instance",
		"TweenInfo",
		"DockWidgetPluginGuiInfo" -- yikes!
	}
}

stds.testez = {
	read_globals = {
		"describe",
		"it", "itFOCUS", "itSKIP",
		"FOCUS", "SKIP", "HACK_NO_XPCALL",
		"expect",
	}
}

ignore = {
	"631"
}

std = "lua51+roblox"
