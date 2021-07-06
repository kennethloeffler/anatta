local Anatta = require(script.Parent.Parent.Anatta)
local Constants = require(script.Parent.Constants)
local t = Anatta.t

local PLUGIN_PRIVATE_COMPONENT_PREFIX = Constants.PluginPrivateComponentPrefix

local renamedComponents = {}
local components = {
	Instance = t.Instance,
	PendingValidation = t.none,
	ForceEntityAttribute = t.none,
	ValidationListener = t.none,
}

for name, definition in pairs(components) do
	renamedComponents[PLUGIN_PRIVATE_COMPONENT_PREFIX .. name] = definition
end

return renamedComponents
