local RunService = game:GetService("RunService")

local SERVER = RunService:IsServer() and not RunService:IsClient()

local Server = SERVER and require(script.Server)
local Client = not SERVER and require(script.Client)

local function Init(EntityManager, entityMap, componentMap)
	if SERVER then
		Server.Init(EntityManager, entityMap, componentMap)
	else
		Client.Init(EntityManager, entityMap, componentMap)
	end
end

return {
	Init = Init

	Reference = SERVER and Server.Reference
	Dereference = SERVER and Server.Dereference
	ReferenceForPlayer = SERVER and Server.ReferenceForPlayer
	DereferenceForPlayer = SERVER and Server.DereferenceForPlayer
	Unique = SERVER and Server.Unique
	UniqueFromPrefab = SERVER and Server.UniqueFromPrefab
	PlayerSerializable = SERVER and Server.PlayerSerializable
	PlayerCreatable = SERVER and Server.ServerCreatable
	
	Step = SERVER and Server.Step or Client.Step
}

