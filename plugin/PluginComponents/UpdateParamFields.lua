local root = script.Parent.Parent.Parent
local Component = require(root.src.Component)

return Component.Define("UpdateParamFields", {
	ComponentType = "none",
	ParamList = {}
})

