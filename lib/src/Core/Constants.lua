local PartialIdWidth = 23

local RunService = game:GetService("RunService")

local IsRunning = RunService:IsRunning()
local IsServer = RunService:IsServer()

--[[
	Entity Masking:
	D = Domain
	V = Version
	I = Partial ID
	P = Pointer

	I+D = Entity ID

	 VERSION   ENTITY ID
	|-------| |---------------------------|
	VVVV VVVV IIII IIII IIII IIII IIII IIID
]]

local Constants = {
	Debug = true,

	-- Domain: server = even; client = odd
	DomainOffset = 0,
	DomainWidth = 1,

	Domain = if not IsRunning then 0 elseif IsServer then 0 else 1,

	-- Partial entity IDs exclude domain
	PartialIdOffset = 1,
	PartialIdWidth = PartialIdWidth, -- 23

	-- Entity ID = Partial ID + Domain
	EntityIdOffset = 0,
	EntityIdWidth = PartialIdWidth + 1,
	EntityIdMask = 0x00FFFFFF,

	-- Version increments per entity cycle
	VersionOffset = PartialIdWidth + 1,
	VersionWidth = 32 - (PartialIdWidth + 1),

	-- Bookkeeping
	NullEntityId = 0,

	-- DOM
	EntityTagName = ".anattaSharedInstance",
	EntityAttributeName = "__entity",
	InstanceRefFolder = "__anattaRefs",
}

return Constants
