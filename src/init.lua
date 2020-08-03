local Manifest = require(script.Manifest)

return function()
	local ecs = Manifest.new()

	return {
		ecs = ecs

		define = function(componentsRoot)
			for _, instance in ipairs(componentsRoot:GetDescendants()) do
				if instance:IsA("ModuleScript") then
					ecs:define(require(instance))
				end
			end
		end
	}
end
