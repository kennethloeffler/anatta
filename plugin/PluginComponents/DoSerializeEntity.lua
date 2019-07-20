local root = script.Parent.Parent.Parent
local Component = require(root.src.Component)

return Component.Define(
	"DoSerializeEntity",
	{ InstanceList = {}, ComponentType = "none", Params = {} }
)

