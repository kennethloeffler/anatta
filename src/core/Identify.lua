--[[

Utility to associate names with numeric identifiers

]]

local IS_STUDIO = game:GetService("RunService"):IsStudio()

local ATTRIBUTES_ENABLED = pcall(function()
	return not not script:GetAttributes()
end)

local PERSISTENT_MASK = 0xFFFF

local Identify = {}
local lookup = {}

local runtimeMax = 0
local persistentMax = 0

local ErrDNE = "No identifier exists for %s"

local function loadFromIntValue()
	for _, obj in ipairs(script:GetChildren()) do
		if typeof(obj) == "IntValue" then
			lookup[obj.Name] = obj.Value
			persistentMax = obj.Value > persistentMax and obj.Value or persistentMax

			obj:Destroy()
		end
	end
end

if ATTRIBUTES_ENABLED then
	-- might have old intvalues from before attributes were enabled
	if next(script:GetChildren()) then
		loadFromIntValue()
	end

	for name, id in pairs(script:GetAttributes()) do
		if type(id) == "number" then
			lookup[name] = id
			persistentMax = id > persistentMax and id or persistentMax

			script:SetAttribute(name, nil)
		end
	end
else
	loadFromIntValue()
end

function Identify.Purge()
	lookup = {}
	runtimeMax = 0
	persistentMax = 0
end

--[[

 Generate an identifier guaranteed to be the same for this run and all
 future runs

]]
function Identify.GeneratePersistent(name)
	assert(IS_STUDIO, "This function may only exectued in Roblox Studio")

	if not lookup[name]
	or bit32.band(lookup[name], PERSISTENT_MASK) == 0 then
		if ATTRIBUTES_ENABLED then
			script:SetAttribute(name, persistentMax)
		else
			local v = Instance.new("IntValue")

			v.Name = name
			v.Value = persistentMax
			v.Parent = script
		end

		lookup[name] = lookup[name]
			and bit32.bor(persistentMax, lookup[name])
			or persistentMax

		persistentMax = persistentMax + 1
	end

	return bit32.band(lookup[name], PERSISTENT_MASK)
end

--[[

 Generate for this name an identifier not guaranteed to be the same
 each run

]]
function Identify.GenerateRuntime(name)
	assert(not lookup[name] or
			  bit32.rshift(lookup[name], 16) == 0,
		  "This name is already associated with a runtime identifier")

	lookup[name] = lookup[name]
		and bit32.bor(bit32.lshift(runtimeMax, 16), lookup[name])
		or bit32.lshift(runtimeMax, 16)

	runtimeMax = runtimeMax + 1

	return runtimeMax
end

--[[

 Change the name of an identifier that has already been named

 Primarily useful for names associated with persistent identifiers,
 when one wants to change the name but keep the same identifier

]]
function Identify.Rename(oldName, newName)
	assert(lookup[oldName], ErrDNE:format(oldName))

	lookup[newName] = lookup[oldName]
	lookup[oldName] = nil
end

function Identify.Persistent(object)
	local identifier = lookup[tostring(object)]

	if identifier then
		return bit32.band(identifier, PERSISTENT_MASK)
	end

	error(ErrDNE:format(tostring(object)))
end

function Identify.Runtime(object)
	local identifier = lookup[tostring(object)]

	if identifier then
		return bit32.rshift(identifier, 16)
	end

	error(ErrDNE:format(tostring(object)))
end

return Identify
