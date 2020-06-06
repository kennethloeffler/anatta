--[[

  Utility to associate names with monotonically increasing integral
  identifiers

]]
local ErrIdentDNE = "%s does not have an identifier"
local ErrAlreadyHas = "%s already has an identifier"
local ErrContextDNE = "context %s does not exist"

local IS_STUDIO = __LEMUR__ or game:GetService("RunService"):IsStudio()
local ATTRIBUTES_ENABLED = pcall(function()
	return not not script:GetAttributes()
end)

local contextFolder

local Identify = {}
Identify.__index = Identify

function Identify.new(context, target)
	return setmetatable({
		context = context or "default",
		lookup = {},
		target = target or script,
		max = 0
	}, Identify)
end

function Identify:toIntValues()
	local folder = contextFolder(self.context, self.target)

	for name, id in pairs(self.lookup) do
		local value = Instance.new("IntValue")

		value.Name = name
		value.Value = id
		value.Parent = folder
	end
end

function Identify:fromIntValues()
	local lookup = self.lookup
	local context = self.context
	local folder = self.target:FindFirstChild(context)

	assert(folder, ErrContextDNE:format(context))
	assert(folder:IsA("Folder"))

	for _, obj in ipairs(folder:GetChildren()) do
		-- typeof doesn't seem to work properly in lemur, so classname it is
		if obj.ClassName == "IntValue" then
			lookup[obj.Name] = obj.Value
			self.max = obj.Value > self.max and obj.Value or self.max
			obj:Destroy()
		end
	end

	folder:Destroy()
end

function Identify:save()
	assert(IS_STUDIO, "this method may only be used in Roblox Studio")

	if ATTRIBUTES_ENABLED then
		self.target:SetAttribute(self.context, self.lookup)
	else
		self:toIntValues()
	end
end

function Identify:load()
	if ATTRIBUTES_ENABLED then
		local lookup = self.lookup
		local context = self.context
		local att = self.target:GetAttribute(context)

		assert(att, ErrContextDNE:format(context))

		-- might have old intvalues from before attributes were enabled
		if next(self.target:GetChildren()) then
			self:fromIntValues()
			return
		end

		for name, id in pairs(att) do
			if type(id) == "number" then
				lookup[name] = id
				self.max = id > self.max and id or self.max
			end
		end

		self.target:SetAttribute(context, nil)
	else
		self:fromIntValues()
	end
end

function Identify:clear()
	self.lookup = {}
	self.max = 0
end

function Identify:generate(name)
	local lookup = self.lookup
	local newMax = self.max + 1

	assert(not lookup[name], ErrAlreadyHas:format(name))

	lookup[name] = newMax
	self.max = newMax

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

function Identify:named(name)
	local ident = self.lookup[name]

	assert(ident, ErrIdentDNE)

	return ident
end

function contextFolder(context, target)
	local folder = target:FindFirstChild(context)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = context
		folder.Parent = target
	end

	return folder
end

return Identify
