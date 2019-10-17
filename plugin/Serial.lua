-- Serial.lua
-- original code by tiffany352

-- Copyright 2019 Kenneth Loeffler

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local SandboxEnv = require(script.Parent.SandboxEnv)

local Serial = {}

function Serial.SerializeValue(data, depth)
	local ty = typeof(data)
	local indent = ("\t"):rep(depth)
	local str

	if ty == "number" or ty == "boolean" then
		str = tostring(data)
	elseif ty == "string" then
		str = string.format("%q", data)
	elseif ty == "table" and data[1] then
		-- array
		str = { "{" }

		for i = 1, #data do
			str[#str + 1] = string.format("%s\t%s,", indent, Serial.SerializeValue(data[i], depth + 1))
		end

		str[#str + 1] = indent.."}"
	elseif ty == "table" then
		-- dict
		str = { "{" }

		local ident = "^([%a_][%w_]*)$"
		local keys = {}

		for key in pairs(data) do
			keys[#keys + 1] = key
		end

		table.sort(keys)

		for i = 1, #keys do
			local key = keys[i]
			local value = data[key]
			local safeKey

			if typeof(key) == "string" and key:match(ident) then
				safeKey = key
			elseif typeof(key) == "string" and tonumber(key) then
				safeKey = string.format("[\"%s\"]", key)
			else
				safeKey = Serial.SerializeValue(key, depth + 1)
			end

			str[#str + 1] = string.format("%s\t%s = %s,", indent, safeKey, Serial.SerializeValue(value, depth + 1))
		end

		str[#str + 1] = next(data) and indent.."}" or "}"
	elseif ty == "Vector2" then
		str = string.format("Vector2.new(%f, %f)", data.X, data.Y)
	elseif ty == "Vector3" then
		str = string.format("Vector3.new(%f, %f, %f)", data.X, data.Y, data.Z)
	elseif ty == "UDim" then
		str = string.format("UDim.new(%f, %f)", data.Scale, data.Offset)
	elseif ty == "UDim2" then
		str = string.format("UDim2.new(%f, %f, %f, %f)", data.X.Scale, data.X.Offset, data.Y.Scale, data.Y.Offset)
	elseif ty == "Color3" then
		str = string.format("Color3.new(%f, %f, %f)", data.R, data.G, data.B)
	elseif ty == "Vector2int16" then
		str = string.format("Vector2int16.new(%d, %d)", data.X, data.Y)
	elseif ty == "Instance" then
		str = string.format("Instance.new(\"%s\")", data.ClassName)
	else
		error("Unexpected type: "..ty)
	end

	if typeof(str) == "table" then
		str = table.concat(str, next(data) and "\n" or "")
	end

	return str
end

function Serial.Serialize(data)
	return "return ".. Serial.SerializeValue(data, 0)
end

function Serial.Deserialize(string)
	local func = loadstring(string)
	setfenv(func, SandboxEnv.lson())
	return func()
end

return Serial
