local root = script.Parent.Parent.Parent
local Component = require(root.src.Component)

return Component.Define("ParamField", {
	ComponentType = "none",
	ParamId = 0,
	ParamValue = false, -- variant
	ParentInstance = Instance.new("Folder"),
	Field = Instance.new("Folder")
})

