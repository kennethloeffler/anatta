-- WorldSmith.lua

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

local Constants = require(script.Constants)
local EntityManager = require(script.EntityManager)
local EntityReplicator = Constants.IS_SERVER or Constants.IS_CLIENT and require(script.EntityReplicator)

return {
	-- functions from EntityManager.lua
	AddComponent = EntityManager.AddComponent,
	GetComponent = EntityManager.GetComponent,
	GetListTypedComponent = EntityManager.GetListTypedComponent,
	GetAllComponentsOfType = EntityManager.GetAllComponentsOfType,

	ComponentAdded = EntityManager.ComponentAdded,
	ComponentKilled = EntityManager.ComponentKilled,

	FilteredEntityAdded = EntityManager.FilteredEntityAdded,
	FilteredEntityRemoved = EntityManager.FilteredEntityRemoved,

	KillComponent = EntityManager.KillComponent,
	KillEntity = EntityManager.KillEntity,
	KillEntityNoDestroy = EntityManager.KillEntityNoDestroy,

	LoadSystem = EntityManager.LoadSystem,
	UnloadSystem = EntityManager.UnloadSystem,
	StartSystems = EntityManager.StartSystems,
	StopSystems = EntityManager.StopSystems,

	Init = EntityManager.Init,
	Destroy = EntityManager.Destroy,

	-- functions from EntityReplicator.lua
	SendAddComponent = EntityReplicator and EntityReplicator.SendAddComponent,
	SendParameterUpdate = EntityReplicator and EntityReplicator.SendParameterUpdate,

	Reference = EntityReplicator and EntityReplicator.Reference,
	Dereference = EntityReplicator and EntityReplicator.Dereference,

	ReferenceGlobal = EntityReplicator and EntityReplicator.ReferenceGlobal,
	DereferenceGlobal = EntityReplicator and EntityReplicator.DereferenceGlobal,

	ReferenceForPrefab = EntityReplicator and EntityReplicator.ReferenceForPrefab,
	DereferenceForPrefab = EntityReplicator and EntityReplicator.DereferenceForPrefab,

	ReferenceForPlayer = EntityReplicator and EntityReplicator.ReferenceForPlayer,
	DereferenceForPlayer = EntityReplicator and EntityReplicator.DereferenceForPlayer,

	Unique = EntityReplicator and EntityReplicator.Unique,
	UniqueFromPrefab = EntityReplicator and EntityReplicator.UniqueFromPrefab
}
