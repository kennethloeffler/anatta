local HttpService = game:GetService("HttpService")

local ErrIdentDNE = "%s does not have an identifier"
local ErrAlreadyHas = "%s already has an identifier"
local ErrNotInStudio = "Identity:save may only be used in Roblox Studio"
local ErrBadLoadTarget = "failed to load identity definitions from %s"

local IS_STUDIO = game:GetService("RunService"):IsStudio()

local Identity = {}
Identity.__index = Identity

function Identity.new()
	return setmetatable({
		lookup = {},
		max = 0
	}, Identity)
end

function Identity:save(target)
	assert(IS_STUDIO, ErrNotInStudio)

	local stringValue = Instance.new("StringValue")
	stringValue.Name = "__identify"
	stringValue.Value = HttpService:JSONEncode(self.lookup)
	stringValue.Parent = target
end

function Identity:tryLoad(target)
	local stringValue = target:FindFirstChild("__identify")
	local errString = ErrBadLoadTarget:format(target:GetFullName())

	if not stringValue or not stringValue:IsA("StringValue") then
		return
	end

	local lookup = HttpService:JSONDecode(stringValue.Value)

	if not next(lookup) then
		warn(errString)
		return
	end

	for name, id in pairs(lookup) do
		if not type(name) == "string" or not type(id) == "number" then
			warn(errString)
			return
		end

		self.lookup[name] = id
		self.max = id > self.max and id or self.max
	end
end

function Identity:clear()
	self.lookup = {}
	self.max = 0
end

function Identity:generate(name)
	local lookup = self.lookup
	local newMax = self.max + 1

	assert(not lookup[name], ErrAlreadyHas:format(name))

	lookup[name] = newMax
	self.max = newMax

	return newMax
end

function Identity:rename(oldName, newName)
	local lookup = self.lookup

	assert(lookup[oldName], ErrIdentDNE:format(oldName))

	lookup[newName] = lookup[oldName]
	lookup[oldName] = nil
end

function Identity:named(name)
	local ident = self.lookup[name]
	assert(ident, ErrIdentDNE:format(name))

	return ident
end

return Identity
