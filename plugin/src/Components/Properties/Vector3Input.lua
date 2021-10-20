local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)

local ComplexStringInput = require(script.Parent.ComplexStringInput)

local vector3Pattern = "^(%-?%d+),(%-?%d+),(%-?%d+)$"

local function createVector3FromString(str)
	local x, y, z = str:match(vector3Pattern)

	if not x or not y or not z then
		return
	end

	return Vector3.new(
		tonumber(x),
		tonumber(y),
		tonumber(z)
	)
end

local function Vector3Input(props)
	return Roact.createElement(ComplexStringInput, {
		Key = props.Key,
		Value = tostring(props.Value),

		Validate = function(raw)
			local vec3 = createVector3FromString(raw:gsub("%s", ""))

			if not vec3 then
				return false
			else
				return true, tostring(vec3)
			end
		end,

		Parse = function(raw)
			return createVector3FromString(raw:gsub("%s", ""))
		end,

		OnChanged = props.OnChanged
	})
end

return Vector3Input