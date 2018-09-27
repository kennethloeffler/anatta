local Manifest = require(script.Manifest)

return function(projectRoot)
	local components = projectRoot:FindFirstChild("Components")
	local ecs = Manifest.new()

	for _, instance in ipairs(components:GetDescendants()) do
		if instance:IsA("ModuleScript") then
			require(instance)(ecs)
		end
	end

	return ecs
end
