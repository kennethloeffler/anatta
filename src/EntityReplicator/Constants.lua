local RunService = game:GetService("RunService")

return {
	-- flag name to bit position
	UPDATE = 0xF
	PARAMS_UPDATE = 0xE,
	ADD_COMPONENT = 0xD,
	KILL_COMPONENT = 0xC,
	IS_REFERENCED = 0xE,
	DESTRUCTION = 0xD,
	PREFAB_REF = 0xC,

	ALL_CLIENTS = 0xABCDEF
	IS_SERVER = RunService:IsServer()
}
