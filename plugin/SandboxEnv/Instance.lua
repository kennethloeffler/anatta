-- Instance.lua
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

local Instance = {}
Instance.__metatable = "Instance"
Instance.__cache = setmetatable({}, {__mode = "kv"})
Instance.InstanceKey = {}

function Instance.new(realInst, mixins)
	if not realInst then
		return nil
	end

	if Instance.__cache[realInst] then
		return Instance.__cache[realInst]
	end

	local proxyMt = {}
	proxyMt.__metatable = "Instance"
	proxyMt.__newindex = error
	local function GetChildren(self)
		local whitelist = mixins and mixins.__childWhitelist
		local filterChildren = {}
		for _,child in pairs(realInst:GetChildren()) do
			if not whitelist or whitelist[child.Name] then
				filterChildren[#filterChildren + 1] = child
			end
		end
		return filterChildren
	end
	function proxyMt:__index(key)
		if key == Instance.InstanceKey then
			return realInst
		end
		assert(typeof(key) == "string")
		if key == "Parent" then
			return Instance.new(realInst.Parent)
		end
		local whitelist = mixins and mixins.__childWhitelist
		if key == "GetChildren" then
			return GetChildren
		end
		if mixins and mixins[key] then
			return mixins[key]
		end
		if not whitelist or whitelist[key] then
			local child = realInst:FindFirstChild(key)
			if child then
				return Instance.new(child)
			end
		end
		error(string.format("No such child %s of %s", key, realInst:GetFullName()))
	end

	local self = {}
	setmetatable(self, proxyMt)

	return self
end

return Instance
