local root = script.Parent.Parent.Parent
local Component = require(root.src.Component)

return Component.Define({"ParamField"}, {
	ParamName = "none",
	EntityList = {},
	ComponentLabel = {},
	Field = Instance.new("Folder")
})
