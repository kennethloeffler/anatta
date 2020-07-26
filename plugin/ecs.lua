local ecs = require(script.Parent.Parent.ecs).new()
local components = script.Parent.components

for _, moduleScript in ipairs(components:GetChildren()) do
	require(moduleScript)(ecs)
end

return ecs
