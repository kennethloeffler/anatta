local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local ComplexStringInput = require(script.Parent.ComplexStringInput)

local vector2Pattern = "^([%-%d%.]+),([%-%d%.]+)$"

local function createVector2FromString(str)
	local x, y = str:match(vector2Pattern)

	if not x or not y then
		return
	end

	return Vector2.new(
		tonumber(x),
		tonumber(y)
	)
end

local function createShortStringFromVector2(vec2)
	return string.format("%.3f, %.3f", vec2.X, vec2.Y)
		:gsub("%.?0+$", "")
		:gsub("%.?0+,", ",")
end

local function Vector2Input(props)
	return Roact.createElement(ComplexStringInput, {
		Key = props.Key,
		Value = createShortStringFromVector2(props.Value),

		Validate = function(raw)
			local vec2 = createVector2FromString(raw:gsub("%s", ""))

			if not vec2 then
				return false
			else
				return true, createShortStringFromVector2(vec2)
			end
		end,

		Parse = function(raw)
			return createVector2FromString(raw:gsub("%s", ""))
		end,

		OnChanged = props.OnChanged
	})
end

return Vector2Input