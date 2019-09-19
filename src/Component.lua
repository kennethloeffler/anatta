local WSAssert = require(script.Parent.WSAssert)

-- Component.lua
local Component = {}

function Component.Define(componentTypeName, paramMap)
	WSAssert(typeof(componentTypeName) == "string", "bad argument #1 (expected string)")
	WSAssert(typeof(paramMap) == "table", "bad argument #2 (expected table)")

	return { componentTypeName, paramMap }
end

return Component

