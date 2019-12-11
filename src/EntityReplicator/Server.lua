-- Server.lua

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

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-- whether ReplicatedStorage and Workspace are automatically converted to prefabs
local AUTO_SERIALIZE_GLOBAL_ENV = false

local Server = {}

local OnPlayerAdded
local NumNetworkIds = 0
local AccumulatedTime = 0

local Remotes = {}
local GlobalBuffer = {}
local PrefabBuffers = {}
local PlayerBuffers = {}
local GlobalRefs = {}
local PrefabRefs = {}
local PlayerReferences = {}
local FreedNetworkIds = {}
local PlayerSerializable = {}
local PlayerCreatable = {}
local StaticPrefabEntities = {}
local RootInstanceEntitiesNum = {}
local PlayersInPrefab = {}
local PrefabsByPlayer = {}

Server.PlayerSerializable = PlayerSerializable
Server.PlayerCreatable = PlayerCreatable

local GetComponentIdFromType = ComponentDesc.GetComponentIdFromType
local GetParamIdFromName = ComponentDesc.GetParamIdFromName
local SerializeEntity = Shared.SerializeEntity
local SerializeUpdate = Shared.SerializeUpdate
local DeserializeNext = Shared.DeserializeNext
local setbit = Shared.setbit
local GetStringFromNetworkId = Shared.GetStringFromNetworkId
local NetworkIdsByInstance = Shared.NetworkIdsByInstance
local InstancesByNetworkId = Shared.InstancesByNetworkId
local QueuedUpdates = Shared.QueuedUpdates

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

	NetworkIdsByInstance[instance] = networkId
	InstancesByNetworkId[networkId] = instance
	CollectionService:AddTag(instance, "__WSReplicatorRef")

	return networkId
end

local function clearBuffer(buffer)
	local bufferEntities = buffer[ENTITIES]
	local bufferParams = buffer[PARAMS]

	for i in ipairs(bufferEntities) do
		bufferEntities[i] = nil
	end

	for i in ipairs(bufferParams) do
		bufferParams[i] = nil
	end

	buffer[ENTITIES_INDEX] = 1
	buffer[PARAMS_INDEX] = 1
end

---Queues a construction message in player's buffer for the referenced entity associated with instance
-- @param player Player
-- @param instance Instance
-- @param networkId number

local function queueConstruction(player, instance, networkId)
	local buffer = PlayerBuffers[player]

	buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX] = SerializeEntity(
		instance, networkId,
		buffer[ENTITIES], buffer[PARAMS],
		buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX],
		nil, true
	)
end

---Queues a destruction message in player's buffer for the referenced entity associated with instance
-- @param player Player
-- @param instance Instance
-- @param networkId number

local function queueDestruction(player, instance, networkId)
	local buffer = PlayerBuffers[player]

	buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX] = SerializeEntity(
		instance, networkId,
		buffer[ENTITIES], buffer[PARAMS],
		buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX],
		true, true
	)
end

---Serializes and sends a prefab to player
-- @param player Player
-- @param rootInstance Instance
-- @param inUnique boolean

local function serializePrefabFor(player, rootInstance, isUnique)
	local static = StaticPrefabEntities[rootInstance]
	local remote = Remotes[player]
	local remoteFunction = remote[REMOTE_FUNCTION]
	local prefabRefsIndex = 1
	local prefabRefsParamIndex = 1
	local prefabRefs = {}
	local prefabRefsParams = {}

	for instance, networkId in pairs(static[PREFAB_REFS]) do
		prefabRefsIndex, prefabRefsParamIndex = SerializeEntity(
			instance, networkId,
			prefabRefs, prefabRefsParams,
			prefabRefsIndex, prefabRefsParamIndex,
			nil, true, instance:IsDescendantOf(rootInstance)
		)
	end

	remote[CAN_RECEIVE_UPDATES] = false
	PlayersInPrefab[rootInstance][player] = true

	rootInstance = isUnique and rootInstance:Clone() or rootInstance
	rootInstance.Parent = isUnique and player.PlayerGui or rootInstance.Parent

	local success = pcall(remoteFunction.InvokeClient, remoteFunction, player, rootInstance, static[ENTITIES], table.unpack(static[PARAMS]))

	if not success then
		if isUnique then
			rootInstance:Destroy()
		end

		return
	end

	remote[REMOTE_EVENT]:FireClient(player, rootInstance, nil, nil, nil, nil, prefabRefs, table.unpack(prefabRefsParams))

	PrefabsByPlayer[player] = rootInstance
	remote[CAN_RECEIVE_UPDATES] = true

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
	local remoteFunction = Remotes[player][REMOTE_FUNCTION]

	instance = instance:Clone()

	pcall(remoteFunction.InvokeClient, remoteFunction, player, instance, entities, table.unpack(params))

	instance:Destroy()
end

local function newPlayerReplicator(player)
	local remoteEvent = Instance.new("RemoteEvent")
	local remoteFunction = Instance.new("RemoteFunction")

	Remotes[player] = {remoteEvent, remoteFunction, true}
	-- { entities, params, entitiesIndex, paramsIndex }
	PlayerBuffers[player] = { {}, {}, 1, 1 }

	remoteEvent.Parent = player.PlayerGui
	remoteFunction.Parent = player.PlayerGui

	remoteEvent.OnClientEvent:Connect(function(_, entities, ...)
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

	if OnPlayerAdded then
		OnPlayerAdded(player)
	end
end

local function destroyPlayerReplicator(player)
	Remotes[player][REMOTE_EVENT]:Destroy()
	Remotes[player][REMOTE_FUNCTION]:Destroy()
	Remotes[player] = nil
	PlayerBuffers[player] = nil
end

-- Public API
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

---Gives the entity associated with instance a networkId (or returns one, if the entity is already referenced) with no other side effects
-- @param instance
-- @return networkId

function Server.Reference(instance)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")

	return NetworkIdsByInstance[instance] or getNetworkId(instance)
end

---Completely dereferences the entity associated with instance from the system
-- Referenced prefab entities that were created before runtime or through NewPrefab will have their instance's Parent property set to the prefab's static entity Folder (rootInstance._s)
-- @param instance

function Server.Dereference(instance)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")

	local networkId = NetworkIdsByInstance[instance]

	if not networkId then
		return
	end

	FreedNetworkIds[#FreedNetworkIds + 1] = networkId
	GlobalRefs[instance] = nil
	PlayerSerializable[instance] = nil
	PlayerCreatable[instance] = nil
	QueuedUpdates[instance] = nil

	if PrefabRefs[instance] then
		local rootInstance = PrefabRefs[instance]
		local static = StaticPrefabEntities[rootInstance]

		PrefabRefs[instance] = nil

		if static then
			static[PREFAB_REFS][instance] = nil
			instance.Parent = rootInstance._s
		end
	end

	NetworkIdsByInstance[instance] = nil
	InstancesByNetworkId[networkId] = nil
end

---References the entity associated with instance for all connected systems
-- If entity is not referenced, this function references it
-- suppressConstructionMessage is a boolean which determines if a construction message is sent
-- @param instance
-- @param supressConstructionMessage

function Server.ReferenceGlobal(instance, supressConstructionMessage)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(supressConstructionMessage == nil or typeof(supressConstructionMessage) == "boolean", "bad argument #2 (expected boolean)")

	local networkId = NetworkIdsByInstance[instance] or getNetworkId(instance)

	if not supressConstructionMessage then
		for _, player in ipairs(Players:GetPlayers()) do
			queueConstruction(player, instance, networkId)
		end
	end

	CollectionService:AddTag(instance, GetStringFromNetworkId(networkId))
	GlobalRefs[instance] = true
end

---Dereferences the entity associated with instance for all connected systems
-- If entity is not referenced, this function returns without doing anything
-- supressDestructionMessage is a boolean which determines if a destruction message is sent
-- @param instance
-- @param supressDestructionMessage

function Server.DereferenceGlobal(instance, supressDestructionMessage)
	WSAssert(typeof(instance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(supressDestructionMessage == nil or typeof(supressDestructionMessage) == "boolean", "bad argument #2 (expected boolean)")

	local networkId = NetworkIdsByInstance[instance]

	if not networkId or not GlobalRefs[instance] then
		return
	end

	if not supressDestructionMessage then
		for _, player in ipairs(Players:GetPlayers()) do
			queueDestruction(player, instance, networkId)
		end
	end

	CollectionService:RemoveTag(instance, GetStringFromNetworkId(networkId))
	GlobalRefs[instance] = nil
end

---References the entity associated with instance for the prefab associated with rootInstance
-- If entity is not referenced, this function references it
-- deepCopyInstance is a boolean which when TRUE places the entity in the prefab's referenced entity folder (rootInstance._r)
-- suppressConstructionMessage is a boolean which determines if a construction message is sent
-- @param rootInstance
-- @param instance
-- @param deepCopyInstance
-- @param supressConstructionMessage

function Server.ReferenceForPrefab(rootInstance, instance, deepCopyInstance, supressConstructionMessage)
	WSAssert(typeof(rootInstance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(CollectionService:HasTag("__WSReplicatorRoot"), "%s is not a prefab", rootInstance.Name)
	WSAssert(deepCopyInstance == nil or typeof(deepCopyInstance) == "boolean", "bad argument #3 (expected boolean)")
	WSAssert(supressConstructionMessage == nil or typeof(supressConstructionMessage) == "boolean", "bad argument #4 (expected boolean)")

	local networkId = NetworkIdsByInstance[instance] or getNetworkId(instance)
	local idStr = GetStringFromNetworkId(networkId)

	if deepCopyInstance then
		instance.Parent = rootInstance._r
		instance.Name = idStr
	end

	if instance:IsDescendantOf(Workspace) or instance:IsDescendantOf(ReplicatedStorage) or instance:IsDescendantOf(Players) then
		CollectionService:AddTag(instance, idStr)
	end

	if not supressConstructionMessage then
		for player in pairs(PlayersInPrefab[rootInstance]) do
			queueConstruction(player, instance, networkId)
		end
	end

	StaticPrefabEntities[rootInstance][PREFAB_REFS][instance] = networkId
end

---Dereferences the entity associated with instance for all connected systems
-- If entity is not referenced for this prefab, this function returns without doing anything
-- supressDestructionMessage is a boolean which determines if a destruction message is sent
-- @param rootInstance
-- @param instance
-- @param supressDestructionMessage

function Server.DereferenceForPrefab(rootInstance, instance, supressDestructionMessage)
	WSAssert(typeof(rootInstance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(CollectionService:HasTag("__WSReplicatorRoot"), "%s is not a prefab", rootInstance.Name)
	WSAssert(supressDestructionMessage == nil or typeof(supressDestructionMessage) == "boolean", "bad argument #4 (expected boolean)")

	local networkId = StaticPrefabEntities[rootInstance][PREFAB_REFS][instance]

	if not networkId then
		return
	end

	local idStr = GetStringFromNetworkId(networkId)

	if not supressDestructionMessage then
		for player in pairs(PlayersInPrefab[rootInstance]) do
			queueDestruction(player, instance, networkId)
		end
	end

	CollectionService:RemoveTag(instance, idStr)
	instance.Name = instance:IsDescendantOf(rootInstance) and "" or instance.Name
	StaticPrefabEntities[rootInstance][PREFAB_REFS][instance] = nil
end

---References the entity associated with instance for player
-- If entity is not referenced, this function references it
-- suppressConstructionMessage is a boolean which determines if a construction message is sent
-- @param player
-- @param instance
-- @param supressConstructionMessage

function Server.ReferenceForPlayer(player, instance, supressConstructionMessage)
	WSAssert(typeof(player) == "Instance" and player:IsA("Player"), "bad argument #1 (expected Player)")
	WSAssert(typeof(instance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(supressConstructionMessage == nil or typeof(supressConstructionMessage) == "boolean", "bad argument #3 (expected boolean)")

	local networkId = NetworkIdsByInstance[instance] or getNetworkId(instance)

	if not PlayerReferences[instance] then
		PlayerReferences[instance] = {}
	end

	local players = PlayerReferences[instance]

	if instance:IsDescendantOf(Workspace) or instance:IsDescendantOf(ReplicatedStorage) or instance:IsDescendantOf(Players) then
		CollectionService:AddTag(instance, GetStringFromNetworkId(networkId))
	end

	if not supressConstructionMessage then
		queueConstruction(player, instance, networkId)
	end

	players[player] = true
end

---Dereferences the entity associated with instance for player
-- If entity is not referenced, this function returns without doing anything
-- supressConstructionMessage is a boolean which determines if a destruction message is sent
-- @param player
-- @param instance
-- @param supressDestructionMessage

function Server.DereferenceForPlayer(player, instance, supressDestructionMessage)
	WSAssert(typeof(player) == "Instance" and player:IsA("Player"), "bad argument #1 (expected Player)")
	WSAssert(typeof(instance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(supressDestructionMessage == nil and typeof(supressDestructionMessage) == "boolean","bad argument #3 (expected boolean)")

	local networkId = NetworkIdsByInstance[instance]

	if not networkId then
		return
	end

	local players = PlayerReferences[instance]

	players[player] = nil

	if not supressDestructionMessage then
		queueDestruction(player, instance, networkId)
	end

	if not next(players) then
		PlayerReferences[instance] = nil
	end
end

---Sends instance and the entity associated with instance uniquely to player via PlayerGui
-- @param player
-- @param instance

function Server.Unique(player, instance, doReference)
	WSAssert(player:IsA("Player"), "bad argument #1 (expected Player)")
	WSAssert(typeof(instance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(doReference == nil or typeof(doReference) == "boolean", "bad argument #3 (expected boolean)")

	local entities = {}
	local params = {}
	local entitiesIndex = 1
	local paramsIndex = 1
	local ref = NetworkIdsByInstance[instance] or (doReference and getNetworkId(instance))
	local networkId = ref or 0

	entities, params = SerializeEntity(
		instance, networkId,
		entities, params,
		entitiesIndex, paramsIndex,
		nil, doReference, nil, true
	)

	if doReference then
		Server.ReferenceForPlayer(player, instance, true)
	end

	coroutine.wrap(doSendUnique, player, instance, entities, params)()
end

---Sends all the entities associated with a globally accessible rootInstance to player
-- @param player
-- @param rootInstance

function Server.FromPrefab(player, rootInstance)
	WSAssert(player:IsA("Player"), "bad argument #1 (expected Player)")
	WSAssert(typeof(rootInstance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(rootInstance:IsDescendantOf(Workspace) or rootInstance:IsDescendantOf(ReplicatedStorage), "Root instance must be a descendant of Workspace or ReplicatedStorage")
	WSAssert(CollectionService:HasTag(rootInstance, "__WSReplicatorRoot"), "%s is not a prefab", rootInstance.Name)

	coroutine.wrap(serializePrefabFor, player, rootInstance, false)()
end

---Sends rootInstance and all its associated entities uniquely to player
-- @param player
-- @param rootInstance

function Server.UniqueFromPrefab(player, rootInstance)
	WSAssert(player:IsA("Player"), "bad argument #1 (expected Player)")
	WSAssert(typeof(rootInstance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(CollectionService:HasTag(rootInstance, "__WSReplicatorRoot"), "%s is not a prefab", rootInstance.Name)

	coroutine.wrap(serializePrefabFor, player, rootInstance, true)()
end

---Removes player from the player list associated with rootInstance
-- @param player
-- @param rootInstance

function Server.RemovePlayerFromPrefab(player, rootInstance)
	WSAssert(player:IsA("Player"), "bad argument #1 (expected Player)")
	WSAssert(typeof(rootInstance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(PlayersInPrefab[rootInstance], "%s is not a prefab", rootInstance.Name)

	PrefabsByPlayer[player] = nil
	PlayersInPrefab[rootInstance][player] = nil
end

---Returns the player list associated with rootInstance
-- @param rootInstance

function Server.GetPlayersInPrefab(rootInstance)
	WSAssert(PlayersInPrefab[rootInstance], "%s is not a prefab", rootInstance.Name)

	return PlayersInPrefab[rootInstance]
end

---Associates a new prefab with rootInstance
-- entitiesFolder is a folder which should contain all the instances in the prefab that are associated with entities
-- @param rootInstance
-- @param entitiesFolder

function Server.NewPrefab(rootInstance, entitiesFolder)
	WSAssert(typeof(rootInstance) == "Instance", "bad argument #1 (expected Instance)")
	WSAssert(typeof(entitiesFolder) == "Instance" and entitiesFolder:IsA("Folder"), "bad argument #2 (expected Folder)")

	local refFolder = Instance.new("Folder")
	local static
	local networkId = 0

	StaticPrefabEntities[rootInstance] = { {}, {}, 1, 1, {} }
	static = StaticPrefabEntities[rootInstance]
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
			networkId = networkId + 1
			static[ENTITIES_INDEX], static[PARAMS_INDEX] = SerializeEntity(
				instance, networkId,
				static[ENTITIES], static[PARAMS],
				static[ENTITIES_INDEX], static[PARAMS_INDEX],
				nil, nil, true
			)
		end
	end

	return rootInstance
end

---Allows players to serialize to the parameter matching paramName of the componentType on instance
-- players may be a single Player instance, a table with keys that are Player instances, or a boolean.
-- If players is a Player instance, only that player may serialize to the parameter. If players is a table,
-- each player in the table may serialize to the table. If players is a boolean or nil, then all players
-- in the game may serialize to the parameter.

-- instance must have a referenced entity associated with it
-- @param players
-- @param instance
-- @param componentType
-- @param paramName

function Server.PlayerSerializable(players, instance, componentType, paramName)
	WSAssert((typeof(players) == "Instance" and players:IsA("Player")) or typeof(players) == "table" or typeof(players) == "boolean", "bad argument #1 (expected Player, table, boolean, or nil)")
	WSAssert(typeof(instance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(typeof(componentType) == "string", "bad argument #3 (expected string)")
	WSAssert(typeof(paramName) == "string", "bad argument #4 (expected string)")

	local networkId = NetworkIdsByInstance[instance]

	WSAssert(networkId, "entity is not referenced")

	if not players then
		PlayerSerializable[instance] = nil

		return
	end

	local struct = PlayerSerializable[instance]
	local componentId = GetComponentIdFromType(componentType)
	local paramId = paramName and GetParamIdFromName(componentId, paramName)
	local paramsField

	if not struct then
		paramsField = paramName and setbit(0, paramId - 1) or 0xFFFF
		PlayerSerializable[instance][1] = players
		PlayerSerializable[instance][componentId + 1] = paramsField
	else
		paramsField = paramName and setbit(struct[componentId + 1] or 0, paramId - 1) or 0xFFFF
		struct[1] = players
		struct[componentId + 1] = paramsField
	end
end

---Allows players to create componentType on instance
-- players may be a single Player instance, a table with keys that are Player instances, or a boolean.
-- If players is a Player instance, only that player may create the component. If players is a table,
-- each player in the table may create the component. If players is a boolean or nil, then all players
-- in the game may create the component.

-- instance must have a referenced entity associated with it
-- @param players
-- @param instance
-- @param componentType
-- @param paramName

function Server.PlayerCreatable(players, instance, componentType)
	WSAssert((typeof(players) == "Instance" and players:IsA("Player")) or typeof(players) == "table" or typeof(players) == "boolean", "bad argument #1 (expected Player, table, boolean, or nil)")
	WSAssert(typeof(instance) == "Instance", "bad argument #2 (expected Instance)")
	WSAssert(typeof(componentType) == "string", "bad argument #3 (expected string)")

	local networkId = NetworkIdsByInstance[instance]

	WSAssert(networkId, "entity is not referenced")

	if not players then
		PlayerCreatable[instance] = nil

		return
	end

	local struct = PlayerCreatable[networkId]
	local componentId = GetComponentIdFromType(componentType)
	local componentOffset = math.floor(componentId * 0.03125)

	if not struct then
		local firstWord = componentOffset == 0 and setbit(0, componentId - 1) or 0
		local secondWord = componentOffset == 1 and setbit(0, componentId - 33) or 0

		PlayerCreatable[instance] = { players, firstWord, secondWord }
	else
		struct[1] = players
		struct[2] = componentOffset == 0 and setbit(struct[2], componentId - 1) or struct[2]
		struct[3] = componentOffset == 1 and setbit(struct[3], componentId - 33) or struct[3]
	end
end

function Server.OnPlayerAdded(func)
	WSAssert(typeof(func) == "function", "bad argument #1 (expected function)")

	OnPlayerAdded = func
end

---Steps the server's replicator
-- default rate 30hz
-- @param dt

function Server.Step(deltaT)
	local playerBuffer
	local playerReferences
	local buffer
	local playerPrefab
	local sendPrefab
	local playerBufferNotEmpty
	local prefab
	local global

	AccumulatedTime = AccumulatedTime + deltaT

	while AccumulatedTime >= TICK_RATE do
		AccumulatedTime = AccumulatedTime - TICK_RATE

		for instance, msgMap in pairs(QueuedUpdates) do
			prefab = PrefabRefs[instance]
			global = GlobalRefs[instance]
			playerReferences = PlayerReferences[instance]

			if prefab and next(PlayersInPrefab[prefab]) then
				buffer = PrefabBuffers[prefab]
			elseif global then
				buffer = GlobalBuffer
			end

			if buffer then
				buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX] = SerializeUpdate(
					buffer[ENTITIES], buffer[PARAMS],
					buffer[ENTITIES_INDEX], buffer[PARAMS_INDEX],
					msgMap
				)
			end

			if playerReferences then
				for player in pairs(playerReferences) do
					playerBuffer = PlayerBuffers[player]
					playerBuffer[ENTITIES_INDEX], playerBuffer[PARAMS_INDEX] = SerializeUpdate(
						playerBuffer[ENTITIES], playerBuffer[PARAMS],
						playerBuffer[ENTITIES_INDEX], playerBuffer[PARAMS_INDEX],
						msgMap
					)
				end
			end

			QueuedUpdates[instance] = nil
		end

		global = next(GlobalBuffer[ENTITIES])

		for _, player in ipairs(Players:GetPlayers()) do
			playerPrefab = PrefabsByPlayer[player]
			playerBuffer = PlayerBuffers[player]
			prefab = PrefabBuffers[playerPrefab]
			playerBufferNotEmpty = next(playerBuffer[ENTITIES])
			sendPrefab = next(prefab[ENTITIES])

			Remotes[player][REMOTE_EVENT]:FireClient(
				player,
				playerPrefab,
				playerBufferNotEmpty and playerBuffer[ENTITIES],
				playerBufferNotEmpty and playerBuffer[PARAMS],
				global and GlobalBuffer[ENTITIES],
				global and GlobalBuffer[PARAMS],
				sendPrefab and prefab[ENTITIES],
				sendPrefab and unpack(prefab[PARAMS])
			)
		end

		for _, prefabBuffer in pairs(PrefabBuffers) do
			clearBuffer(prefabBuffer)
		end

		clearBuffer(GlobalBuffer)
	end
end

---Serializes extant prefabs and starts listening to PlayerAdded and PlayerRemoved to create buffers for clients

function Server.Init()
	if AUTO_SERIALIZE_GLOBAL_ENV then
		CollectionService:AddTag(Workspace, "__WSReplicatorRoot")
		CollectionService:AddTag(ReplicatedStorage, "__WSReplicatorRoot")
	end

	local RootInstances = CollectionService:GetTagged("__WSReplicatorRoot")
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
				local static = StaticPrefabEntities[rootInstance]

				if instance:HasTag("__WSReplicatorRef") then
					local networkId = getNetworkId(instance)

					instance.Name = GetStringFromNetworkId(networkId)
					instance.Parent = rootInstance._r
					static[PREFAB_REFS][instance] = networkId
					PrefabRefs[instance] = rootInstance
				else
					RootInstanceEntitiesNum[rootInstance] = RootInstanceEntitiesNum[rootInstance] + 1
					instance.Name = GetStringFromNetworkId(RootInstanceEntitiesNum[rootInstance])
					instance.Parent = rootInstance._s

					static[ENTITIES_INDEX], static[PARAMS_INDEX] = SerializeEntity(
						instance, RootInstanceEntitiesNum[rootInstance],
						static[ENTITIES], static[PARAMS],
						static[ENTITIES_INDEX], static[PARAMS_INDEX],
						nil, nil, true
					)
				end
			end
		end
	end

	-- if we took too long, create buffers for extant players
	for _, player in ipairs(Players:GetPlayers()) do
		newPlayerReplicator(player)
	end

	Players.PlayerAdded:Connect(newPlayerReplicator)
	Players.PlayerRemoving:Connect(destroyPlayerReplicator)
end

return Server
