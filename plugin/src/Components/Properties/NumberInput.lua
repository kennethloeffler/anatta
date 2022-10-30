local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local ComplexStringInput = require(script.Parent.ComplexStringInput)

local function NumberInput(props)
	return Roact.createElement(ComplexStringInput, {
		Key = props.Key,
		Value = props.Value,
		LayoutOrder = props.LayoutOrder,

		Filter = function(raw)
			return raw:match("%-?%d*%.?%d*")
		end,

		Validate = function(raw)
			if raw == "" then
				raw = 0
			end

			raw = tonumber(raw)

			if props.Max then
				raw = math.min(raw, props.Max)
			end

			if props.Min then
				raw = math.max(raw, props.Min)
			end

			return true, raw
		end,

		Parse = function(raw)
			return tonumber(raw)
		end,

		OnChanged = props.OnChanged,
	})
end

return NumberInput
