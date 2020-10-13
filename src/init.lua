local Constants = require(script.Constants)
local Manifest = require(script.Manifest)
local Strict = require(script.Strict)

return function(projectRoot)
	local manifest = Constants.STRICT
		and Strict(Manifest.new(projectRoot))
		or Manifest.new(projectRoot)

	manifest:load(projectRoot)

	return manifest
end
