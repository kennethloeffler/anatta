-- Constants.lua

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
