--[[

Utility to associate names with numeric identifiers

]]

local IS_STUDIO = game:GetService("RunService"):IsStudio()

local ATTRIBUTES_ENABLED = pcall(function()
	script:GetAttributes()
end)

local Ident = {}

local lookup = {}

-- begin at 1 for runtime identifiers so that they can map properly to
-- indices of array-like tables
local runtimeMax = 1
local persistentMax = 0


--[[

 Generate an identifier guaranteed to be the same for all future runs

]]
function Ident.GeneratePersistent(name)
	assert(IS_STUDIO, "This function can only exectued from Roblox Studio")
end

--[[

 Generate an identifier guaranteed to be the same for this run

]]
function Ident.GenerateRuntime(name)
	lookup[name] = runtimeMax + 1
	runtimeMax = runtimeMax + 1

	return runtimeMax
end

--[[

 Specify an alias for an existing name

]]
function Ident.Alias(nameToAlias, alias)
end

function Ident.GetPersistent(object)
end

function Ident.GetRuntime(object)
	local identifier = lookup[tostring(object)]

	if identifier then
		return bit32.rshift(identifier, 16)
	end

	error(("No identifier exists for %s"):format(tostring(object)))
end
