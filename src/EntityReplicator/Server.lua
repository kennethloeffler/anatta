local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ComponentDesc = require(script.Parent.Parent.ComponentDesc)
local Shared = require(script.Shared)
local WSAssert = require(script.Parent.Parent.WSAssert)

local SERVER = RunService:IsServer() and not RunService:IsClient()

local Server = {}

-- Internal
------------------------------------------------------------------------------------------------------------------------------
local NumNetworkIds = 0
local Remotes = {}
local FreedNetworkIds = {}
local PlayerReferences = {}
local PlayerBuffers = {}
local NetworkIdsByInstance = {}
local InstancesByNetworkId = {}
local PlayerSerializable = {}
local PlayerCreatable = {}
local StaticPrefabEntities = {}

local bExtract = bit32.extract
local bReplace = bit32.replace
local blShift = bit32.lshift
local bOr = bit32.bor
local bAnd = bit32.band
local bNot = bit32.bnot

local serializeNext = Shared.SerializeNext
local serializeNextUpdate = Shared.SerializeNextUpdate
local deserializeNext = Shared.DeserializeNext
local setBitAtPos = Shared.SetBitAtPos
local getIdStringFromNum = Shared.GetIdStringFromNum
local getIdNumFromString = Shared.GetIdNumFromString

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
		networkId = NumNetworkIds + 1
	end
	InstancesByNetworkId[networkId] = instance
	NetworkIdsByInstance[instance] = networkId
	CollectionService:AddTag(instance, "__WSReplicatorRef")
	return networkId
end


---Serializes the prefab associated with rootInstance for player
-- @param player Player
-- @param rootInstance Instance
-- @return entities
-- @return params
local function serializePrefabFor(player, rootInstance)
	local static = StaticPrefabEntities[rootInstance]
	local entities = static[1]
	local params = static[2]
	local entitiesIndex = static[3]
	local paramsIndex = static[4]
		
	for instance, networkId in pairs(static[5]) do
		entitiesIndex, paramsIndex = serializeNext(instance, networkId, entities, params, entitiesIndex, paramsIndex, true)
		PlayerReferences[player][instance] = true
	end

	return static[1], static[2]
end

---Queues a construction message in player's buffer for the networked entity with networkId associated with instance 
-- !!! not thread safe !!!
-- @param player Player
-- @param instance Instance
-- @param networkId number
local function sendConstructionTo(player, instance, networkId)
	local playerBuffer = PlayerBuffers[player]
	local entitiesIndex, paramsIndex = serializeNext(instance, networkId, playerBuffer[1], playerBuffer[2], playerBuffer[3], playerBuffer[4])
	playerBuffer[3] = entitiesIndex
	playerBuffer[4] = paramsIndex
end

---Queues a destruction message in player's buffer for the networked entity with networkId associated with instance 
-- !!! not thread safe !!!
-- @param player Player
-- @param instance Instance
-- @param networkId number
local function sendDestructionTo(player, instance, networkId)
	local playerBuffer = PlayerBuffers[player]
	local entitiesIndex, paramsIndex = serializeNext(instance, networkId, playerBuffer[1], playerBuffer[2], playerBuffer[3], playerBuffer[4], true, true)
	playerBuffer[3] = entititesIndex
	playerBuffer[4] = paramsIndex
end

---Sends the prefab associated with rootInstance to player
-- if isUnique == true, then the instance is cloned and sent uniquely to the player via PlayerGui
-- @param player Player
-- @param rootInstance Instance
-- @param entities table 
-- @param params table
-- @param isUnique boolean
local function doSendPrefab(player, rootInstance, entities, params, isUnique)
	rootInstance = isUnique and rootInstance:Clone() or rootInstance
	rootInstance.Parent = isUnique and player.PlayerGui or rootInstance.Parent
	Remotes[player][2]:InvokeClient(player, rootInstance, entities, unpack(params))
	if isUnique then
		rootInstance:Destroy()
	end
end

---Clones the instance and sends it uniquely to player via PlayerGui along with its associated entity data
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
	WSAssert(SERVER)
	local remoteEvent = Instance.new("RemoteEvent")
	local remoteFunction = Instance.new("RemoteFunction")

	Remotes[player] = {remoteEvent, remoteFunction}
	PlayerReferences[player] = {}
	-- { entities, params, entitiesIndex, paramsIndex, canReceiveUpdates }
	PlayerBuffers[player] = { {}, {}, 1, 0, false }

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
	Remotes[player][1]:Destroy()
	Remotes[player] = nil
	PlayerReferences[player] = {}
	PlayerQueues[player] = nil
end

-- Public API
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Server.Reference(instance, sendConstructionMessage)
	WSAssert(SERVER)

	local networkId = NetworkIdsByInstance[instance] or getNetworkId(instance)
	for player, references in pairs(PlayerReferences) do
		references[instance] = true
		if sendConstructionMessage then
			sendConstruction(player, instance, networkId)
		end
	end
end

function Server.Dereference(instance, sendDestructionMessage)
	WSAssert(SERVER)

	local networkId = NetworkIdsByInstance[instance]

	if not networkId then
		return
	end

	for player, references in pairs(PlayerReferences) do
		if sendDestructionMessage and references[instance] then
			sendDestruction(player, instance, networkId)
		end
		references[instance] = nil
	end
		
	InstancesByNetworkId[networkId] = nil
	NetworkIdsByInstance[instance] = nil
end

function Server.ReferenceForPlayer(player, instance, sendConstructionMessage)
	WSAssert(SERVER)

	local networkId = NetworkIdsbyInstance[instance] or getNetworkId(instance)
	PlayerReferences[player][instance] = true
	if sendConstructionMessage then
		sendConstruction(player, instance, networkId)
	end
end

function Server.DereferenceForPlayer(player, instance, sendDestructionMessage)
	WSAssert(SERVER)

	PlayerReferences[player][instance] = nil
	if sendDestructionMessage then
		sendDestruction(player, instance, networkId)
	end
end

function Server.Unique(player, instance)
	WSAssert(SERVER)

	local entities = {}
	local params = {}
	local entitiesIndex = 1
	local paramsIndex = 0
	local ref = NetworkIdsByInstance[instance]
	local networkId = ref or 1
	entities, params = serializeNext(instance, networkId, entities, params, entitiesIndex, paramsIndex, nil, ref and true or nil)
	doSendUnique(player, instance, entities, params)
end

function Server.FromPrefab(player, rootInstance)
	WSAssert(SERVER)

	local entities, params = serializePrefabFor(player, rootInstance)
	coroutine.resume(coroutine.create(pcall, doSendPrefab, player, rootInstance, entities, params, false))
end

function Server.UniqueFromPrefab(player, rootInstance)
	WSAssert(SERVER)

	local entities, params = serializePrefabFor(player, rootInstance)
	coroutine.resume(coroutine.create(pcall, doSendPrefab, player, rootInstance, entities, params, true))
end

function Server.PlayerSerializable(player, instance, componentType, paramName)
	WSAssert(SERVER)

	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local paramId = paramName and ComponentDesc.GetParamIdFromName(componentId, paramName)
	local networkId = networkIdsByInstance[networkId]
	local struct

	if not networkId then
		networkId = getNetworkId[instance]
		struct = { player, 0 }
		PlayerSerializable[networkId] = struct
	else
		struct = PlayerSerializable[networkId]
	end

	struct[1] = player
	struct[2] = paramId and setBitAtPos(struct[2], paramId - 1) or bNot(0)
end

function Server.PlayerCreatable(player, instance, componentType)
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local networkId = networkIdsByInstance[networkId]
	local offset = math.ceil(componentId) + 1
	local struct

	if not networkId then
		networkId = getNetworkId[instance]
		struct = { player, 0, 0, 0, 0 }
		PlayerCreatable[networkId] = struct
	else
		struct = PlayerCreatable[networkId]
	end

	struct[1] = player
	struct[offset] = setBitAtPos(struct[offset], componentId - 1 + (32 * offset - 1))
end

function Server.Step()
end

function Server.Init(entityManager, entityMap, componentMap)
	local PrefabEntities = {}

	Server.EntityManager = entityManager
	Server._entityMap = entityMap
	Server._componentMap = componentMap

	CollectionService:AddTag(Workspace, "__WSReplicatorRootInstance")
	CollectionService:AddTag(ReplicatedStorage, "__WSReplicatorRootInstance")

	local RootInstances = CollectionService:GetTagged("__WSReplicatorRootInstance")
	local Entities = CollectionService:GetTagged("__WSEntity")

	for _, rootInstance in pairs(RootInstances) do
		local entitiesFolder = Instance.new("Folder")
		entitiesFolder.Name = "__WSEntities"
		entitiesFolder.Parent = rootInstance
		RootInstanceEntitiesNum[rootInstance] = 0
		PrefabEntities[rootInstance] = { {}, {}, 1, 0, {} }
	end

	for _, instance in pairs(Entities) do
		for _, rootInstance in pairs(RootInstances) do
			if instance:IsDescendantOf(rootInstance) then
				local name
				local prefab = PrefabEntities[rootInstance]
				if instance:HasTag("__WSReplicatorRef")
					local networkId = getNetworkId(instance)
					local id = getTempIdString(networkId)
					static[5][instance] = networkId
					name = id
				else
					RootInstanceEntitiesNum[rootInstance] = RootInstanceEntitiesNum[rootInstance] + 1
					local id = getTempIdString(RootInstanceEntitiesNum[rootInstance])
					name = id
					static[1], static[2], static[3], static[4] = serializeNext(instance, id, static[1], static[2], static[3], static[4])
				end
				instance.Name = name
				instance.Parent = rootInstance.__WSEntities
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
