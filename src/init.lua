local Constants = require(script.Constants)
local Manifest = require(script.Manifest)
local Strict = require(script.Strict)

return function()
	local ecs = Manifest.new()

	return Constants.STRICT and Strict(ecs) or ecs
end
