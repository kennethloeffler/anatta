local src = script.Parent.Parent.Parent
local Component = require(src.Component)

return Component.Define(
	"SelectionUpdate",
	{ EntityList = {} }
)
