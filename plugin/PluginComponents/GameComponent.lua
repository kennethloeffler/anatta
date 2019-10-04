local root = script.Parent.Parent.Parent
local Component = require(root.src.Component)

return Component.Define("GameComponent", {
	ComponentId = 0,
	ComponentType = "none",
	DefaultParams = {},
})

