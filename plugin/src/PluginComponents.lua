local Anatta = require(script.Parent.Parent.Anatta)
local Constants = require(script.Parent.Constants)
local t = Anatta.t

local PRIVATE_COMPONENT_PREFIX = Constants.PrivateComponentPrefix

local renamedComponents = {}
local components = {
	Instance = t.Instance,
	PendingValidation = t.none,
	ForceEntityAttribute = t.none,
	ValidationListener = t.none,
}

for name, definition in pairs(components) do
	renamedComponents[PRIVATE_COMPONENT_PREFIX .. name] = definition
end

return renamedComponents
