local Constants = require(script.Constants)
local EntityManager = require(script.EntityManager)
local EntityReplicator = Constants.IS_SERVER or Constants.IS_CLIENT and require(script.EntityReplicator)

return {
	-- EntityManager
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

	LoadSystem = EntityManager.LoadSystem,
	UnloadSystem = EntityManager.UnloadSystem,
	StartSystems = EntityManager.StartSystems,
	StopSystems = EntityManager.StopSystems,

	Init = EntityManager.Init,
	Destroy = EntityManager.Destroy,

	-- EntityReplicator
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
	UniqueFromPrefab = EntityReplicator and EntityReplicator.UniqueFromPrefab,
}
