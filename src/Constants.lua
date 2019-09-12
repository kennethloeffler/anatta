local RunService = game:GetService("RunService")

return {
	-- Replicator constants
	IS_UPDATE = 0xF,
	PARAMS_UPDATE = 0xE,
	ADD_COMPONENT = 0xD,
	KILL_COMPONENT = 0xC,
	IS_REFERENCED = 0xE,
	IS_DESTRUCTION = 0xD,
	IS_PREFAB = 0xC,
	IS_UNIQUE = 0xB,
	ALL_CLIENTS = true,

	-- misc.
	MAX_COMPONENT_PARAMETERS = 16,
	MAX_UNIQUE_COMPONENTS = 64,

	IS_SERVER = RunService:IsServer() and (not RunService:IsStudio() or RunService:IsRunMode()),
	IS_CLIENT = RunService:IsClient() and (not RunService:IsStudio() or RunService:IsRunMode()),
	IS_STUDIO = RunService:IsStudio(),
	IS_RUN_MODE = RunService:IsRunMode()
}

