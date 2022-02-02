local EntityIdWidth = 20

local RunService = game:GetService("RunService")

return {
	Debug = true,
	DomainOffset = 31,
	EntityIdWidth = EntityIdWidth,
	EntityIdOffset = 0,
	EntityAttributeName = "__entity",
	InstanceRefFolder = "__anattaRefs",
	Domain = (RunService:IsServer() or RunService:IsEdit()) and 0 or 1,
	NullEntityId = 0,
	SharedInstanceTagName = ".anattaSharedInstance",
	VersionOffset = EntityIdWidth,
	VersionWidth = 31 - EntityIdWidth,
}
