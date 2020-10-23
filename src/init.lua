local Manifest = require(script.Manifest)
local Strict = require(script.Strict)

return function(params)
	local projectRoot = params.projectRoot
	local strict = params.strict

	local manifest = strict ~= false and Strict(Manifest.new(projectRoot))
		or Manifest.new(projectRoot)

	manifest:load(projectRoot)

	return manifest
end
