-- Component.lua
local WSAssert = require(script.Parent.WSAssert)

local Component = {}

function Component.Define(componentTypeName, paramMap)

	WSAssert(typeof(componentTypeName) == "string", "expected string")
	WSAssert(typeof(paramMap) == "table", "expected table")
	
	for i, v in pairs(paramMap) do
		WSAssert(typeof(i) == "string", "expected string")
	end

	return componentTypeName, paramMap
end

return Component
