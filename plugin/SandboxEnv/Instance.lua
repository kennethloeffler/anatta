-- Instance.lua
-- original code by tiffany352
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
