local Constants = require(script.Parent.Constants)

local Client = Constants.IS_CLIENT and require(script.Client)
local Server = Constants.IS_SERVER and require(script.Server)
local Shared = require(script.Shared)

return {
	Init = function(EntityManager, entityMap, componentMap)
		Shared.Init(EntityManager, entityMap, componentMap)

		if Server then
			Server.Init()
		elseif Client then
			Client.Init()
		end
	end,

	-- client-side functions
	SendAddComponent = Client and Client.SendAddComponent,
	SendParameterUpdate = Client and Client.SendParameterUpdate,

	-- server-side functions
	Reference = Server and Server.Reference,

	ReferenceGlobal = Server and Server.ReferenceGlobal,
	DereferenceGlobal = Server and Server.DereferenceGlobal,

	ReferenceForPlayer = Server and Server.ReferenceForPlayer,
	DereferenceForPlayer = Server and Server.DereferenceForPlayer,

	ReferenceForPrefab = Server and Server.ReferenceForPrefab,
	DereferenceForPrefab = Server and Server.DereferenceForPrefab,

	Unique = Server and Server.Unique,
	UniqueFromPrefab = Server and Server.UniqueFromPrefab,

	PlayerSerializable = Server and Server.PlayerSerializable,
	PlayerCreatable = Server and Server.PlayerCreatable,

	-- shared functions
	Step = Server and Server.Step or Client.Step,
	Dereference = Server and Server.Dereference or Shared.OnDereference
}
