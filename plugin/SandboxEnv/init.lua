-- SandboxEnv.lua
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

local Instance = require(script.Instance)

local gameWhitelist = {
	ReplicatedStorage = true,
	ServerScriptService = true,
	ServerStorage = true,
}
local sandboxGame = Instance.new(game, {
	GetService = function(self, service)
		assert(typeof(service) == "string")
		if gameWhitelist[service] then
			return Instance.new(game:GetService(service))
		end
	end,
	__childrenWhitelist = gameWhitelist
})

local SandboxEnv = {}

function SandboxEnv.new(script, baseEnv)
	local env = {}

	env.script = Instance.new(script)

	env.game = sandboxGame

	env._G = env
	env.assert = assert
	env.error = error
	env.pairs = pairs
	env.ipairs = ipairs
	env.next = next
	env.pcall = pcall
	env.print = print
	env.select = select
	env.tonumber = tonumber
	env.tostring = tostring
	env.type = type
	env.typeof = typeof
	env.unpack = unpack
	env.xpcall = xpcall
	env.setmetatable = setmetatable

	-- libraries
	env.string = string
	env.math = math
	env.table = table
	env.utf8 = utf8

	-- atomic types
	env.Axes = Axes
	env.BrickColor = BrickColor
	env.CFrame = CFrame
	env.Color3 = Color3
	env.ColorSequence = ColorSequence
	env.ColorSequenceKeypoint = ColorSequenceKeypoint
	env.Faces = Faces
	env.NumberRange = NumberRange
	env.NumberSequence = NumberSequence
	env.NumberSequenceKeypoint = NumberSequenceKeypoint
	env.PhysicalProperties = PhysicalProperties
	env.Ray = Ray
	env.Rect = Rect
	env.Region3 = Region3
	env.TweenInfo = TweenInfo
	env.UDim = UDim
	env.UDim2 = UDim2
	env.Vector2 = Vector2
	env.Vector3 = Vector3
	env.Vector2int16 = Vector2int16
	-- excluded: Instance, DockWidgetPluginGuiInfo, PathWaypoint, Random, Vector3int16, Region3int16

	function env.require(module)
		if typeof(module) ~= "Instance" then
			module = module[Instance.InstanceKey]
		end
		local func = loadstring(module.Source, "@" .. module:GetFullName())
		setfenv(func, SandboxEnv.new(module))
		return func()
	end

	return env
end

-- much more restricted environment for data serialization
function SandboxEnv.lson()
	local env = {}

	-- atomic types
	env.Axes = Axes
	env.BrickColor = BrickColor
	env.CFrame = CFrame
	env.Color3 = Color3
	env.ColorSequence = ColorSequence
	env.ColorSequenceKeypoint = ColorSequenceKeypoint
	env.Faces = Faces
	env.NumberRange = NumberRange
	env.NumberSequence = NumberSequence
	env.NumberSequenceKeypoint = NumberSequenceKeypoint
	env.PhysicalProperties = PhysicalProperties
	env.Ray = Ray
	env.Rect = Rect
	env.Region3 = Region3
	env.TweenInfo = TweenInfo
	env.UDim = UDim
	env.UDim2 = UDim2
	env.Vector2 = Vector2
	env.Vector3 = Vector3
	env.Vector2int16 = Vector2int16
	-- excluded: Instance, DockWidgetPluginGuiInfo, PathWaypoint, Random, Vector3int16, Region3int16

	return env
end

return SandboxEnv
