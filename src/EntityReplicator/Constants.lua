local RunService = game:GetService("RunService")

return {
	IS_UPDATE = 0xF,
	PARAMS_UPDATE = 0xE,
	ADD_COMPONENT = 0xD,
	KILL_COMPONENT = 0xC,
	IS_REFERENCED = 0xE,
	IS_DESTRUCTION = 0xD,
	IS_PREFAB = 0xC,
	IS_UNIQUE = 0xB,

	ALL_CLIENTS = true,
	IS_SERVER = RunService:IsServer(),
	IS_STUDIO = RunService:IsStudio(),
	IS_RUN_MODE = RunService:IsRunMode()
}

