local Manifest = require(script.Parent.ecs.Manifest)

return function(projectRoot)
	local components = projectRoot:FindFirstChild("components")
	local ecs = Manifest.new()

	for _, instance in ipairs(components:GetChildren()) do
		if instance:IsA("ModuleScript") then
			require(instance)(ecs)
		end
	end

	return ecs
end
