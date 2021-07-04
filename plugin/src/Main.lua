local Anatta = require(script.Parent.Parent.Anatta)

local Constants = require(script.Parent.Constants)
local Systems = script.Parent.Systems
local t = require(script.Parent.Parent.Anatta.Library.Core.Type)

local PRIVATE_COMPONENT_PREFIX = Constants.PrivateComponentPrefix

return function(plugin)
	local components = {
		AssociatedInstance = t.Instance,
		Selected = t.none,
	}

	for name, definition in pairs(components) do
		components[PRIVATE_COMPONENT_PREFIX .. name] = definition
	end

	local anatta = Anatta.new(components)

	anatta:loadSystems(Systems)

	plugin:beforeUnload(function()
		anatta:unloadSystems(Systems)
	end)
end
