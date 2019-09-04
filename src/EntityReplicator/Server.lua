local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ComponentDesc = require(script.Parent.Parent.ComponentDesc)
local Shared = require(script.Shared)
local WSAssert = require(script.Parent.Parent.WSAssert)

-- buffer enumerations
local ENTITIES = 1
local PARAMS = 2
local ENTITIES_INDEX = 3
local PARAMS_INDEX = 4
local REMOTE_FUNCTION = 2
local REMOTE_EVENT = 1
local PREFAB_REFS = 5
local CAN_RECEIVE_UPDATES = 3

-- network step rate
local TICK_RATE = 1/30

local Server = {}

local NumNetworkIds = 0
local AccumulatedTime = 0

local Remotes = {}
local PrefabBuffers = {}
local PlayerBuffers = {}
local FreedNetworkIds = {}
local PlayerReferences = {}
local PlayerSerializable = {}
local PlayerCreatable = {}
local StaticPrefabEntities = {}

Server.PlayerSerializable = PlayerSerializable
Server.PlayerCreatable = PlayerCreatable

local SerializeEntity = Shared.SerializeEntity
local DeserializeNext = Shared.DeserializeNext
local setBitAtPos = Shared.setbit
local getIdStringFromNum = Shared.GetIdStringFromNum
local getIdNumFromString = Shared.GetIdNumFromString
local onNewReference = Shared.OnNewReference
local onDereference = Shared.OnDereference
local QueueUpdate = Shared.QueueUpdate
local NetworkIdsByInstance = Shared.NetworkIdsByInstance
local InstancesByNetworkId = Shared.InstancesByNetworkId

---Gets an available networkId
-- @param instance Instance
local function getNetworkId(instance)
	local networkId
	local numFreedNetworkIds = #FreedNetworkIds

	if numFreedNetworkIds > 0 then
		networkId = FreedNetworkIds[numFreedNetworkIds]
		FreedNetworkIds[numFreedNetworkIds] = nil
	else
		networkId = NumNetworkIds + 1
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
	buffer[PARAMS_INDEX] = 1
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
	local prefabRefsParamIndex = 1
	local prefabRefs = {}
	local prefabRefsParams = {}

	for instance, networkId in pairs(static[PREFAB_REFS]) do
		prefabRefIndex, prefabParamIndex = SerializeEntity(
			instance, networkId,
			prefabRefs, prefabRefsParams,
			prefabRefsIndex, prefabRefsParamIndex,
			true
		)
	end

	Remotes[player][CAN_RECEIVE_UPDATES] = false

	rootInstance = isUnique and rootInstance:Clone() or rootInstance
	rootInstance.Parent = isUnique and player.PlayerGui or rootInstance.Parent

	Remotes[player][REMOTE_FUNCTION]:InvokeClient(player, rootInstance, static[ENTITIES], table.unpack(static[PARAMS]))
	Remotes[player][REMOTE_EVENT]:FireClient(player, rootInstance, prefabRefs, table.unpack(prefabRefsParams))
	PlayersInPrefab[rootInstance][player] = true

	Remotes[player][CAN_RECEIVE_UPDATES] = true

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
	Remotes[player][REMOTE_FUNCTION]:InvokeClient(player, instance, entities, table.unpack(params))
	instance:Destroy()
end

local function newPlayerReplicator(player)
	-- probably unnecessary for each client to have its own private remote pair... but why not?
	local remoteEvent = Instance.new("RemoteEvent")
	local remoteFunction = Instance.new("RemoteFunction")

	Remotes[player] = {remoteEvent, remoteFunction, true}
	-- { entities, params, entitiesIndex, paramsIndex }
	PlayerBuffers[player] = { {}, {}, 1, 1 }

	remoteEvent.Parent = player.PlayerGui
	remoteFunction.Parent = player.PlayerGui

	remoteEvent.OnClientEvent:Connect(function(player, entities, ...)
		local entitiesIndex = 1
		local paramsIndex = 1

		for _ in next, entities do
			entitiesIndex, paramsIndex = DeserializeNext(entities, table.pack(...), entitiesIndex, paramsIndex, player)

			-- player sent bad data
			if not entitiesIndex then
				-- player:Kick()
				return
			end
		end
	end)
end

local function destroyPlayerReplicator(player)
	Remotes[player][REMOTE_EVENT]:Destroy()
	Remotes[player][REMOTE_FUNCTION]:Destroy()
	Remotes[player] = nil
	PlayerBuffers[player] = nil
end

-- Public API
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function Server.Reference(instance)
	return NetworkIdsByInstance[instance] or getNetworkId(instance)
end

function Server.ReferenceGlobal(instance, supressConstructionMessage)
	local networkId = NetworkIdsByInstance[instance] or getNetworkId(instance)

	CollectionService:AddTag(instance, GetIdStringFromNum(networkId))

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

function Server.ReferenceFor(player, instance, supressConstructionMessage)
	local networkId = NetworkIdsByInstance[instance] or getNetworkId(instance)

	if not PlayerReferences[instance] then
		PlayerReferences[instance] = {}
	end

	local players = PlayerReferences[instance]

	if instance:IsDescendantOf(Workspace) or instance:IsDescendantOf(ReplicatedStorage) or instance:IsDescendantOf(Players) then
		CollectionService:AddTag(instance, GetIdStringFromNum(networkId))
	end

	if not supressConstructionMessage then
		queueConstruction(player, instance, networkId)
	end

	players[player] = true
end

function Server.DereferenceFor(player, instance, supressDestructionMessage)
	local networkId = NetworkIdsByInstance[instance]

	if not networkId then
		return
	end

	local players = PlayerReferences[instance]

	if players and players[player] then
		if not supressDestructionMessage then
			queueDestruction(player, instance, networkId)
		end

		players[player] = nil

		if not next(players) then
			PlayerReferences[instance] = nil
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
	local paramsIndex = 1
	local ref = NetworkIdsByInstance[instance]
	local networkId = ref or 0

	entities, params = SerializeEntity(
		instance, networkId,
		entities, params,
		entitiesIndex, paramsIndex,
		nil, ref and true or nil
	)

	coroutine.resume(coroutine.create(pcall, doSendUnique, player, instance, entities, params))
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
	local refFolder = Instance.new("Folder")
	local static

	StaticPrefabEntities[rootInstance] = { {}, {}, 1, 1, {} }
	static = staticPrefabEntities[rootInstance]
	PrefabBuffers[rootInstance] = { {}, {}, 1, 1 }
	PlayersInPrefab[rootInstance] = {}
	entitiesFolder.Name = "_s"
	refFolder.Name = "_r"
	refFolder.Parent = rootInstance

	for _, instance in ipairs(entitiesFolder:GetChildren()) do
		if CollectionService:HasTag(instance, "__WSReplicatorRef") then
			static[PREFAB_REFS][instance] = NetworkIdsByInstance[instance]
			PrefabRefs[instance] = rootInstance
			instance.Parent = refFolder
		else
			static[ENTITIES_INDEX], static[PARAMS_INDEX] = SerializeEntity(
				instance, networkId,
				static[ENTITIES], static[PARAMS]
				static[ENTITIES_INDEX], static[PARAMS_INDEX]
			)
		end
	end

	return rootInstance
end

function Server.PlayerSerializable(players, instance, componentType, paramName)
	local networkId = NetworkIdsByInstance[networkId]

	WSAssert(networkId, "Entity is not referenced")

	if not players then
		PlayerSerializable[networkId] = nil

		return
	end

	local struct = PlayerSerializable[networkId]
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local componentOffset = math.floor(componentId * 0.03125) -- componentId / 32
	local paramId = paramName and ComponentDesc.GetParamIdFromName(componentId, paramName)
	local paramsField
	local buffer

	if not struct then
		local firstWord = componentOffset == 0 and setBitAtPos(0, componentId - 1) or 0
		local secondWord = componentOffset == 1 and setBitAtPos(0, componentId - 33) or 0

		paramsField = paramName and setBitAtPos(0, paramId - 1) or 0xFFFF
		PlayerSerializable[networkId][1] = players
		PlayerSerializable[networkId][componentId + 1] = paramsField
	else
		paramsField = paramName and setBitAtPos(struct[componentId + 1] or 0, paramId - 1) or 0xFFFF
		struct[1] = players or ALL_CLIENTS
		struct[componentId + 1] = paramsField
	end
end

function Server.PlayerCreatable(players, instance, componentType)
	local networkId = NetworkIdsByInstance[networkId]

	WSAssert(networkId, "Entity is not referenced")

	if not players then
		PlayerCreatable[networkId] = nil

		return
	end

	local struct = PlayerCreatable[networkId]
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)

	if not struct then
		local firstWord = componentOffset == 0 and setBitAtPos(0, componentId - 1) or 0
		local secondWord = componentOffset == 0 and setBitAtPos(0, componentId - 33) or 0

		PlayerCreatable[networkId] = { players, firstWord, secondWord }
	else
		struct[1] = players or ALL_CLIENTS
		struct[2] = componentOffset == 0 and setBitAtPos(struct[2], componentId - 1) or struct[2]
		struct[3] = componentOffset == 1 and setBitAtPos(struct[3], componentId - 33) or struct[3]
	end
end

function Server.Step(dt)
	local playerBuffer
	local buffer
	local prefab

	AccumulatedTime = AccumulatedTime + dt

	while AccumulatedTime >= TICK_RATE do
		AccumulatedTime = AccumulatedTime - TICK_RATE

		for instance, msgMap in pairs(QueuedUpdates) do
			prefab = PrefabRefs[instance]
			playerReferences = PlayerReferences[instance]
			buffer = prefab and PrefabBuffers[prefab] or GlobalBuffer

			buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX] = SerializeUpdate(
				buffer[ENTITIES], buffer[PARAMS],
				buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX],
				msgMap
			)

			if playerReferences then
				for player in pairs(playerReferences) do
					playerBuffer = PlayerBuffers[player]
					playerBuffer[ENTITIES_INDEX], playerBuffer[PARAMS_INDEX] = SerializeUpdate(
						playerBuffer[ENTITIES], playerBuffer[PARAMS],
						playerBuffer[ENTITIES_INDEX], playerBuffer[PARAMS_INDEX],
						mspMap
					)
				end
			end

			QueuedUpdates[instance] = nil
		end

		for _, player in ipairs(Players:GetPlayers()) do
			playerBuffer = PlayerBuffers[player]
			playerRefs = PlayerRefs[player]

			if next(PlayerBuffers[ENTITIES]) then
				Remotes[player][REMOTE_EVENT]:FireClient(player, nil, playerBuffer[ENTITIES], table.unpack(playerBuffer[PARAMS]))
				clearBuffer[playerBuffer]
			end

			if next(GlobalBuffer[ENTIITES]) then
				Remotes[player][REMOTE_EVENT]:FireClient(player, nil, GlobalBuffer[ENTIITES], table.unpack(GlobalBuffer[PARAMS]))
			end
		end

		if next(GlobalBuffer[ENTITIES]) then
			clearBuffer(GlobalBuffer)
		end

		for rootInstance, prefabBuffer in pairs(PrefabBuffers) do
			if next(prefabBuffer[ENTITIES]) and next(PlayersInPrefab[rootInstance]) then
				for player in pairs(PlayersInPrefab[rootInstance]) do
					if Remotes[player][CAN_RECEIVE_UPDATES] then
						Remotes[player][REMOTE_EVENT]:FireClient(player, nil, prefabBuffer[ENTITIES], table.unpack(prefabBuffer[PARAMS]))
					end
				end

				clearBuffer(prefabBuffer)
			end
		end
	end
end

function Server.Init()
	local PrefabEntities = {}

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
					static[PREFAB_REFS][instance] = networkId
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

