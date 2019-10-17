-- EntityReplicator.lua

-- Copyright 2019 Kenneth Loeffler

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

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
