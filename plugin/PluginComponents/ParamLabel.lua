local root = script.Parent.Parent.Parent
local Component = require(root.src.Component)

return Component.Define("ParamField", {
	ComponentType = "none",
	ParamId = 0,
	ParamValue = false, -- variant
	Entity = Instance.new("Folder")
})

