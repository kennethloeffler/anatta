local WSAssert = require(script.Parent.WSAssert)

-- Component.lua
local Component = {}

function Component.Define(componentTypeName, paramMap, isEthereal)
	WSAssert(typeof(componentTypeName) == "string" or (typeof(componentTypeName) == "table" and typeof(componentTypeName[1]) == "string"), "bad argument #1 (expected string)")
	WSAssert(typeof(paramMap) == "table", "bad argument #2 (expected table)")

	return { componentTypeName, paramMap, isEthereal }
end

return Component

