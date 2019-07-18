-- Component.lua
local Component = {}

function Component.Define(componentTypeName, paramMap)
	return {componentTypeName, paramMap}
end

return Component
