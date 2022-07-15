local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local ComplexStringInput = require(script.Parent.ComplexStringInput)

local function IntegerInput(props)
	return Roact.createElement(ComplexStringInput, {
		Key = props.Key,
		Value = props.Value,
		ZIndex = props.ZIndex,

		Filter = function(raw)
			return raw:match("%d*%.?%d*")
		end,

		Validate = function(raw)
			if raw == "" then
				raw = 0
			end

			return true, math.floor(tonumber(raw) + 0.5)
		end,

		Parse = function(raw)
			return tonumber(raw)
		end,

		OnChanged = props.OnChanged,
	})
end

return IntegerInput
