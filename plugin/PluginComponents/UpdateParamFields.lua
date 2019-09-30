local root = script.Parent.Parent.Parent
local Component = require(root.src.Component)

return Component.Define("UpdateParamFields", {
	OldLabel = Instance.new("Folder"),
	ParamList = {},
	ParentInstance = Instance.new("Folder")
})

