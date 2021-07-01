local Anatta = require(script.Parent.Parent.Anatta)

local getComponentDefinitions = require(script.Parent.getComponentDefinitions)

local Systems = script.Parent.Systems

return function(plugin)
	local componentDefinitions = getComponentDefinitions()
	local anatta = Anatta.new(componentDefinitions)

	anatta:loadSystems(Systems)

	plugin:beforeUnload(function()
		anatta:unloadSystems(Systems)
	end)
end
