local root = script.Parent.Parent.Parent
local Component = require(root.src.Component)

return Component.Define("ComponentLabel", {
	ComponentType = "none",
	ParamList = {},
	Open = false,
	Entity = Instance.new("Folder")
})
