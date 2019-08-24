local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ComponentDesc = require(script.Parent.Parent.ComponentDesc)
local Shared = require(script.Shared)
local WSAssert = require(script.Parent.Parent.WSAssert)

local SERVER = RunService:IsServer() and not RunService:IsClient()

-- buffer enumerations
local ENTITIES = 1
local PARAMS = 2
local ENTITIES_INDEX = 3
local PARAMS_INDEX = 4
local REMOTE_FUNCTION = 2
local REMOTE_EVENT = 1

local Server = {}

-- Internal
------------------------------------------------------------------------------------------------------------------------------
local NumNetworkIds = 0
local Remotes = {}
local PrefabBuffers = {}
local MasterBuffer = {}
local PlayerBuffers = {}
local FreedNetworkIds = {}
local PlayerReferences = {}
local PlayerSerializable = {}
local PlayerCreatable = {}
local StaticPrefabEntities = {}

local bExtract = bit32.extract
local bReplace = bit32.replace
local blShift = bit32.lshift
local bOr = bit32.bor
local bAnd = bit32.band
local bNot = bit32.bnot

local SharedStep = Shared.Step
local serializeNext = Shared.SerializeNext
local serializeNextUpdate = Shared.SerializeNextUpdate
local deserializeNext = Shared.DeserializeNext
local setBitAtPos = Shared.SetBitAtPos
local getIdStringFromNum = Shared.GetIdStringFromNum
local getIdNumFromString = Shared.GetIdNumFromString
local onNewReference = Shared.OnNewReference
local onDereference = Shared.OnDereference
local QueueUpdate = Shared.QueueUpdate
local NetworkIdsByInstance = Shared.NetworkIdsByInstance
local InstancesByNetworkId = Shared.InstancesByNetworkId

Server._componentMap = nil
Server._entityMap = nil
Server.EntityManager = nil

---Gets an available networkId
-- @param instance Instance
local function getNetworkId(instance)
	local networkId
	local numFreedNetworkIds = #FreedNetworkIds
	if numFreedNetworkIds > 0 then
		networkId = FreedNetworkIds[numFreedNetworkIds]
		FreedNetworkIds[numFreedNetworkIds] = nil
	else
		networkId = NumNetworpkIds + 1
	end
	onNewReference(instance, networkId)
	CollectionService:AddTag(instance, "__WSReplicatorRef")
	return networkId
end

local function clearBuffer(buffer)
	local bufferEntities = buffer[ENTITIES]
	local bufferParams = buffer[PARAMS]

	for i, v in ipairs(bufferEntities) do
		bufferEntities[i] = nil
	end

	for i, v in ipairs(bufferParams) do
		bufferParams[i] = nil
	end

	buffer[ENTITIES_INDEX] = 1
	buffer[PARAMS_INDEX] = 0
end

---Queues a construction message in player's buffer for the networked entity with networkId associated with instance
-- @param player Player
-- @param instance Instance
-- @param networkId number
local function queueConstruction(player, instance, networkId)
	local buffer = PlayerBuffers[player]

	buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX] = SerializeEntity(
		instance, networkId,
		buffer[ENTITIES], buffer[PARAMS]
		buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX]
	)
end

---Queues a destruction message in player's buffer for the networked entity with networkId associated with instance
-- @param player Player
-- @param instance Instance
-- @param networkId number
local function queueDestruction(player, instance, networkId)
	local buffer = PlayerBuffers[player]

	buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX] = SerializeEntity(
		instance, networkId,
		buffer[ENTITIES], buffer[PARAMS]
		buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX],
		true
	)
end

---Serializes and sends a prefab to player
-- @param player Player
-- @param rootInstance Instance
-- @param inUnique boolean
local function serializePrefabFor(player, rootInstance, isUnique)
	local static = StaticPrefabEntities[rootInstance]
	local prefabRefsIndex = 1
	local prefabRefsParamIndex = 0
	local prefabRefs = {}
	local prefabRefsParams = {}

	for instance, networkId in pairs(static[5]) do
		prefabRefIndex, prefabParamIndex = serializeNext(
			instance, networkId,
			prefabRefs, prefabRefsParams,
			prefabRefsIndex, prefabRefsParamIndex,
			true
		end
	end

	PlayerBuffers[player][5] = false
	rootInstance = isUnique and rootInstance:Clone() or rootInstance
	rootInstance.Parent = isUnique and player.PlayerGui or rootInstance.Parent
	Remotes[player][REMOTE_FUNCTION]:InvokeClient(player, rootInstance, static[1], unpack(static[2]))
	Remotes[player][REMOTE_EVENT]:FireClient(player, rootInstance, prefabRefs, unpack(prefabRefsParams))
	PlayerBuffers[player][5] = true
	PlayersInPrefab[rootInstance][player] = true

	if isUnique then
		rootInstance:Destroy()
	end
end

---Clones an instance and sends it uniquely to player via PlayerGui along with its associated entity data
-- @param player Player
-- @param instance Instance
-- @param entities table
-- @param params table
local function doSendUnique(player, instance, entities, params)
	instance = instance:Clone()
	Remotes[player][2]:InvokeClient(player, instance, entities, unpack(params))
	instance:Destroy()
end

local function newPlayerReplicator(player)
	-- probably unnecessary for each client to have its own private remote pair... but why not?
	local remoteEvent = Instance.new("RemoteEvent")
	local remoteFunction = Instance.new("RemoteFunction")

	Remotes[player] = {remoteEvent, remoteFunction}
	PlayerReference[player] = {}
	-- { entities, params, entitiesIndex, paramsIndex, canReceiveUpdates }
	PlayerBuffers[player] = { {}, {}, 1, 0, true }

	remoteEvent.Parent = player.PlayerGui
	remoteFunction.Parent = player.PlayerGui

	remoteEvent.OnClientEvent:Connect(function(player)
	end)

	remoteFunction.OnClientInvoke = function(player)
	end
end

local function destroyPlayerReplicator(player)
	WSAssert(SERVER)
	Remotes[player][1]:Destroy()
	Remotes[player][2]:Destroy()
	Remotes[player] = nil
	PlayerReferences[player] = {}
	PlayerBuffers[player] = nil
end

-- Public API
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Server.ReferenceGlobal(instance, supressConstructionMessage)
	local networkId = NetworkIdsByInstance[instance] or getNetworkId(instance)

	if not supressConstructionMessage then
		for _, player in ipairs(Players:GetPlayers()) do
			queueConstruction(player, instance, networkId)
		end
	end

	GlobalRefs[instance] = true
end

function Server.DereferenceGlobal(instance, supressDestructionMessage)
	local networkId = NetworkIdsByInstance[instance]

	if not networkId or not GlobalRefs[instance] then
		return
	end

	if not supressDestructionMessage then
		for _, player in ipairs(Players:GetPlayers()) do
			queueDestruction(player, instance, networkId)
		end
	end

	GlobalRefs[instance] = nil
	onDereference(instance, networkId)
end

function Server.ReferenceFor(players, instance, supressConstructionMessage)
	local networkId = NetworkIdsByInstance[instance] or getNetworkId(instance)
	local temp

	if typeof(players) == "Instance" then
		temp = not supressConstructionMessage and queueConstruction(players, instance, networkId)
		PlayerRefs[player][instance] = true
	elseif typeof(players) == "table" then
		for player in pairs(players) do
			temp = not supressConstructionMessage and queueConstruction(player, instance, networkId)
			PlayerRefs[player][instance] = true
		end
	end
end

function Server.DereferenceFor(players, instance, supressDestructionMessage)
	local networkId = NetworkIdsByInstance[instance]
	local temp

	if not networkId then
		return
	end

	if typeof(players) == "Instance" then
		if PlayerRefs[players][instance] then
			temp = not supressDestructionMessage and queueDestruction(players, instance, networkId)
			PlayerRefs[player][instance] = nil
		end
	else
		for player in pairs(players) do
			if PlayerRefs[players][instance] then
				temp = not supressDestructionMessage and queueDestruction(player, instance, networkId)
				PlayerRefs[player][instance] = nil
			end
		end
	end
end

function Server.Unique(player, instance)
	WSAssert(player:IsA("Player"), "bad argument #1 (expected Player)")
	WSAssert(typeof(rootInstance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(CollectionService:HasTag(instance, "__WSEntity"), "%s is not a prefab", instance.Name)

	local entities = {}
	local params = {}
	local entitiesIndex = 1
	local paramsIndex = 0
	local ref = NetworkIdsByInstance[instance]
	local networkId = ref or 1

	entities, params = serializeNext(
		instance, networkId,
		entities, params,
		entitiesIndex, paramsIndex,
		nil, ref and true or nil
	)

	coroutine.resume(coroutine.create(pcall, doSendUnique, player, instance, entities, params)))
end

function Server.FromPrefab(player, rootInstance)
	WSAssert(player:IsA("Player"), "bad argument #1 (expected Player)")
	WSAssert(typeof(rootInstance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(CollectionService:HasTag(rootInstance, "__WSReplicatorRoot"), "%s is not a prefab", rootInstance.Name)

	coroutine.resume(coroutine.create(pcall, serializePrefabFor, player, rootInstance, false))
end

function Server.UniqueFromPrefab(player, rootInstance)
	WSAssert(player:IsA("Player"), "bad argument #1 (expected Player)")
	WSAssert(typeof(rootInstance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(CollectionService:HasTag(rootInstance, "__WSReplicatorRoot"), "%s is not a prefab", rootInstance.Name)

	coroutine.resume(coroutine.create(pcall, serializePrefabFor, player, rootInstance, true))
end

function Server.RemovePlayerFromPrefab(player, rootInstance)
	WSAssert(player:IsA("Player"), "bad argument #1 (expected Player)")
	WSAssert(typeof(rootInstance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(CollectionService:HasTag(rootInstance, "__WSReplicatorRoot"), "%s is not a prefab", rootInstance.Name)

	PlayersInPrefab[rootInstance][player] = nil
end

function Server.GetPlayersInPrefab(rootInstance)
	return PlayersInPrefab[rootInstance]
end

function Server.NewPrefab(rootInstance, entitiesFolder)
	StaticPrefabEntities[rootInstance] = { {}, {}, 1, 0, {} }
	PrefabBuffers[rootInstance] = { {}, {}, 1, 0 }
	PlayersInPrefab[rootInstance] = {}
	entitiesFolder.Name = "_s"
	local refFolder = Instance.new("Folder")
	local static = StaticPrefabEntities[rootInstance]
	refFolder.Parent = rootInstance
	for _, instance in ipairs(entitiesFolder:GetChildren()) do
		if CollectionService:HasTag(instance, "__WSReplicatorRef") then
			static[5][instance] = NetworkIdsByInstance[instance]
			instance.Parent = refFolder
		else
			static[ENTITIES_INDEX], static[PARAMS_INDEX] = SerializeEntity(
				instance, networkId,
				static[ENTITIES], static[PARAMS]
				static[ENTITIES_INDEX], static[PARAMS_INDEX]
			)
			instance.Parent = entitiesFolder
		end

	return rootInstance
end

function Server.PlayerSerializable(players, instance, componentType, paramName)
	local networkId = NetworkIdsByInstance[networkId]
	local buffer

	WSAssert(networkId, "Entity is not referenced")

	local struct = PlayerSerializable[networkId]
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local componentOffset = math.floor(componentId * 0.03125) -- componentId / 32
	local paramId = paramName and ComponentDesc.GetParamIdFromName(componentId, paramName)
	local paramsField

	if not struct then
		local firstWord = componentOffset == 0 and setBitAtPos(0, componentId - 1) or 0
		local secondWord = componentOffset == 1 and setBitAtPos(0, componentId - 33) or 0

		networkId = getNetworkId(instance)
		paramsField = paramName and setBitAtPos(0, paramId - 1) or 0xFFFF
		PlayerSerializable[networkId] = { playerArg or ALL_CLIENTS }
		PlayerSerializable[componentId + 1] = paramsField
	else
		paramsField = paramName and setBitAtPos(struct[componentId + 1] or 0, paramId - 1) or 0xFFFF
		struct[1] = players or ALL_CLIENTS
		struct[componentId + 1] = paramsField
	end
end

function Server.PlayerCreatable(players, instance, componentType, playerArg)
	local networkId = NetworkIdsByInstance[networkId]

	WSAssert(networkId, "Entity is not referenced")

	local struct = PlayerCreatable[networkId]
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)

	if not struct then
		local firstWord = componentOffset == 0 and setBitAtPos(0, componentId - 1) or 0
		local secondWord = componentOffset == 0 and setBitAtPos(0, componentId - 33) or 0

		networkId = getNetworkId(instance)
		PlayerCreatable[networkId] = { playerArg or ALL_CLIENTS, firstWord, secondWord }
	else
		struct[1] = playerArg or ALL_CLIENTS
		struct[2] = componentOffset == 0 and setBitAtPos(struct[2], componentId - 1)
		struct[3] = componentOffset == 1 and setBitAtPos(struct[3], componentId - 33)
	end
end

function Server.Step()
	local entities
	local params
	local entitiesIndex = 0
	local paramsIndex = 1
	local map

	if next(QueuedUpdates) then
		local buffer
		local prefab

		for instance, msgMap in pairs(QueuedUpdates) do
			prefab = PrefabRefs[instance]
			buffer = prefab and PrefabBuffers[prefab] or GlobalBuffer
			buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX] = SerializeUpdate(
				buffer[ENTITIES], buffer[PARAMS],
				buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX],
				msgMap
			)
			QueuedUpdates[instance] = nil
		end
	end

	for rootInstance, buffer in pairs(PrefabBuffers) do
		entities = buffer[1]
		params = buffer[2]

		if next(entities) and next(PlayersInPrefab[rootInstance]) then
			for player in pairs(PlayersInPrefab[rootInstance]) do
				Remotes[player][REMOTE_EVENT]:FireClient(player, nil, entities, unpack(params))
				clearBuffer(buffer)
			end
		end
	end

	for player, buffer in pairs(PlayerBuffers) do
		entities = buffer[1]
		params = buffer[2]

		if next(entities) then
			Remotes[player][REMOTE_EVENT]:FireClient(player, nil, entities, unpack(params))
			clearBuffer(buffer)
		end
	end
end

function Server.Init(entityManager, entityMap, componentMap, shouldAutoReplicate)
	local PrefabEntities = {}

	Shared.Init(entityMap, componentMap, PlayerCreatabled, PlayerSerializable)

	Server.EntityManager = entityManager
	Server._entityMap = entityMap
	Server._componentMap = componentMap

	CollectionService:AddTag(Workspace, "__WSReplicatorRootInstance")
	CollectionService:AddTag(ReplicatedStorage, "__WSReplicatorRootInstance")

	local RootInstances = CollectionService:GetTagged("__WSReplicatorRootInstance")
	local Entities = CollectionService:GetTagged("__WSEntity")

	for _, rootInstance in pairs(RootInstances) do
		local StaticFolder = Instance.new("Folder")
		local RefFolder = Instance.new("Folder")
		StaticFolder.Name = "_s"
	    RefFolder.Name = "_r"
		StaticFolder.Parent = rootInstance
		RefFolder.Parent = rootInstance
		RootInstanceEntitiesNum[rootInstance] = 0
		PrefabBuffers[rootInstance] = { {}, {}, 1, 0, {} }
		StaticPrefabEntities[rootInstance] = { {}, {}, 1, 0, {} }
	end

	for _, instance in pairs(Entities) do
		for _, rootInstance in pairs(RootInstances) do
			if instance:IsDescendantOf(rootInstance) then
				local name
				local static = StaticPrefabEntities[rootInstance]

				if instance:HasTag("__WSReplicatorRef")
					local networkId = getNetworkId(instance)

					instance.Name = getTempIdString(networkId)
					instance.Parent = rootInstance._r
					static[5][instance] = networkId
					PrefabRefs[instance] = rootInstance
				else
					RootInstanceEntitiesNum[rootInstance] = RootInstanceEntitiesNum[rootInstance] + 1
					instance.Name = getTempIdString(RootInstanceEntitiesNum[rootInstance])
					instance.Parent = rootInstance._s

					static[ENTITIES], static[PARAMS], static[ENTITIES_INDEX], static[PARAMS_INDEX] = serializeEntity(
						instance, id,
						static[ENTITIES], static[PARAMS],
						static[ENTITIES_INDEX], static[PARAMS_INDEX]
					)
				end
			end
		end
	end

	Players.PlayerAdded:Connect(newPlayerReplicator)
	Players.PlayerRemoving:Connect(destroyPlayerReplicator)

	for _, player in ipairs(Players:GetPlayers()) do
		newReplicatorFor(player)
	end
end

return Server
