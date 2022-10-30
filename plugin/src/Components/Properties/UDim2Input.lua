local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local ComplexStringInput = require(script.Parent.ComplexStringInput)

local uDim2Pattern = "^([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)$"

local function createUDim2FromString(str)
	local xScale, xOffset, yScale, yOffset = str:match(uDim2Pattern)

	if not xScale or not xOffset or not yScale or not yOffset then
		return
	end

	return UDim2.new(xScale, xOffset, yScale, yOffset)
end

local function createShortStringFromUDim2(uDim2: UDim2)
	return string.format("%.3f, %.0f, %.3f, %.0f", uDim2.X.Scale, uDim2.X.Offset, uDim2.Y.Scale, uDim2.Y.Offset)
		:gsub("%.?0+$", "")
		:gsub("%.?0+,", ",")
end

local function UDim2Input(props)
	return Roact.createElement(ComplexStringInput, {
		Key = props.Key,
		Value = createShortStringFromUDim2(props.Value),
		LayoutOrder = props.LayoutOrder,

		Validate = function(raw)
			local udim2 = createUDim2FromString(raw:gsub("%s", ""))

			if not udim2 then
				return false
			else
				return true, createShortStringFromUDim2(udim2)
			end
		end,

		Parse = function(raw)
			return createUDim2FromString(raw:gsub("%s", ""))
		end,

		OnChanged = props.OnChanged,
	})
end

return UDim2Input
