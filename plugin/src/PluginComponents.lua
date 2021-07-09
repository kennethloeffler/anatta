local Anatta = require(script.Parent.Parent.Anatta)
local Constants = require(script.Parent.Constants)
local t = Anatta.t

local PLUGIN_PRIVATE_COMPONENT_PREFIX = Constants.PluginPrivateComponentPrefix

local components = {
	ForceEntityAttribute = t.none,
	Instance = t.Instance,
	PendingValidation = t.none,
	ScheduledDestruction = t.number,
	ValidationListener = t.none,
}

local renamedComponents = {}

for name, definition in pairs(components) do
	renamedComponents[PLUGIN_PRIVATE_COMPONENT_PREFIX .. name] = definition
end

return renamedComponents
