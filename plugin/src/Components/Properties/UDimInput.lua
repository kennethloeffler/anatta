local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local ComplexStringInput = require(script.Parent.ComplexStringInput)

local uDimPattern = "^([%-%d%.]+),([%-%d%.]+)$"

local function createUDimFromString(str)
	local scale, offset = str:match(uDimPattern)

	if not scale or not offset then
		return
	end

	return UDim.new(scale, offset)
end

local function createShortStringFromUDim(uDim: UDim)
	return string.format("%.3f, %.0f", uDim.Scale, uDim.Offset):gsub("%.?0+$", ""):gsub("%.?0+,", ",")
end

local function UDimInput(props)
	return Roact.createElement(ComplexStringInput, {
		Key = props.Key,
		Value = createShortStringFromUDim(props.Value),

		Validate = function(raw)
			local udim = createUDimFromString(raw:gsub("%s", ""))

			if not udim then
				return false
			else
				return true, createShortStringFromUDim(udim)
			end
		end,

		Parse = function(raw)
			return createUDimFromString(raw:gsub("%s", ""))
		end,

		OnChanged = props.OnChanged,
	})
end

return UDimInput
