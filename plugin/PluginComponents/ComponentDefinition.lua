local root = script.Parent.Parent.Parent
local Component = require(root.src.Component)

return Component.Define("ComponentDefinition", {
	ComponentType = "none",
	ComponentId = 0,
	ListTyped = false,
	ParamList = {}
})
