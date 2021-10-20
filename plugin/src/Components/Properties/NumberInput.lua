local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local ComplexStringInput = require(script.Parent.ComplexStringInput)

local function NumberInput(props)
	return Roact.createElement(ComplexStringInput, {
		Key = props.Key,
		Value = props.Value,

		Filter = function(raw)
			return raw:gsub("%D", "")
		end,

		Parse = function(raw)
			return tonumber(raw)
		end,

		OnChanged = props.OnChanged
	})
end

return NumberInput