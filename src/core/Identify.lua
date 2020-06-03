--[[

Utility to associate names with numeric identifiers

]]
local ErrIdentDNE = "%s does not have an identifier"
local ErrAlreadyHas = "%s already has an identifier"
local ErrContextDNE = "context %s does not exist"

local IS_STUDIO = __LEMUR__ or game:GetService("RunService"):IsStudio()
local ATTRIBUTES_ENABLED = pcall(function()
	return not not script:GetAttributes()
end)
local PERSISTENT_WIDTH = 16
local PERSISTENT_MASK = bit32.rshift(0xFFFFFFFF, PERSISTENT_WIDTH)

local contextFolder

local Identify = {}
Identify.__index = Identify

function Identify.new(context, target)
	return setmetatable({
		context = context,
		lookup = {},
		target = target or script,
		runtimeMax = 0,
		persistentMax = 0
	}, Identify)
end

function Identify:fromIntValues()
	local lookup = self.lookup
	local context = self.context
	local newMax = self.persistentMax
	local names = self.target:FindFirstChild(context)

	assert(names, ErrContextDNE:format(context))

	for _, obj in ipairs(names:GetChildren()) do
		-- typeof doesn't seem to work properly in lemur
		if obj.ClassName == "IntValue" then
			lookup[obj.Name] = obj.Value
			self.persistentMax = obj.Value > newMax and obj.Value or newMax
			obj:Destroy()
		end
	end
end

function Identify:load()
	if ATTRIBUTES_ENABLED then
		local lookup = self.lookup
		local newMax = self.persistentMax
		local context = self.context
		local names = self.target:GetAttribute(context)

		assert(names, ErrContextDNE:format(context))

		-- might have old intvalues from before attributes were enabled
		if next(self.target:GetChildren()) then
			self:fromIntValues()
			return
		end

		for name, id in pairs(names) do
			if type(id) == "number" then
				lookup[name] = id
				self.persistentMax = id > newMax and id or newMax
			end
		end
	else
		self:fromIntValues()
	end
end

function Identify:save()
end

function Identify:clear()
	self.lookup = {}
	self.runtimeMax = 0
	self.persistentMax = 0
end

--[[

 Generate an identifier guaranteed to be the same for this run and all
 future runs

]]
function Identify:generatePersistent(name)
	assert(IS_STUDIO, "This function may only exectued in Roblox Studio")

	local lookup = self.lookup
	local newMax = self.persistentMax + 1
	local context = self.context
	local ident = lookup[name] and bit32.band(lookup[name], PERSISTENT_MASK)

	assert(not ident or ident == 0, ErrAlreadyHas:format(name))

	if not ident or ident == 0 then
		if ATTRIBUTES_ENABLED then
			local names = self.target:GetAttribute(context) or {}

			names[name] = newMax

			self.target:SetAttribute(context, names)
		else
			local v = Instance.new("IntValue")

			v.Name = name
			v.Value = newMax
			v.Parent = contextFolder(context, self.target)
		end

		lookup[name] = bit32.bor(newMax, ident or 0)
		self.persistentMax = newMax
	end

	return newMax
end

--[[

 Generate for this name an identifier not guaranteed to be the same
 each run

]]
function Identify:generateRuntime(name)
	local lookup = self.lookup
	local newMax = self.runtimeMax + 1
	local ident = lookup[name]

	assert(not ident or bit32.rshift(ident, PERSISTENT_WIDTH) == 0, ErrAlreadyHas:format(name))

	lookup[name] = bit32.bor(bit32.lshift(newMax, PERSISTENT_WIDTH), ident or 0)

	self.runtimeMax = newMax

	return newMax
end

--[[

 Change the name of an identifier that has already been named

 Primarily useful for names associated with persistent identifiers,
 when one wants to change the name but keep the same identifier

]]
function Identify:rename(oldName, newName)
	local lookup = self.lookup

	assert(lookup[oldName], ErrIdentDNE:format(oldName))

	lookup[newName] = lookup[oldName]
	lookup[oldName] = nil
end

function Identify:persistent(name)
	local identifier = self.lookup[name]

	assert(identifier, ErrIdentDNE:format(name))

	local n = bit32.band(identifier, PERSISTENT_MASK)

	assert(n ~= 0, ErrIdentDNE:format(name))

	return n
end

function Identify:runtime(name)
	local identifier = self.lookup[name]

	assert(identifier, ErrIdentDNE:format(name))

	local n = bit32.rshift(identifier, PERSISTENT_WIDTH)

	assert(n ~= 0, ErrIdentDNE:format(name))

	return n
end

contextFolder = function(context, target)
	local folder = target:FindFirstChild(context)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = context
		folder.Parent = target
	end

	return folder
end

return Identify
