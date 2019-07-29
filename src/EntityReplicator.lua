-- EntityReplicator.lua (experimental)
-- This module is one giant hack. Be careful please

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ComponentDesc = require(script.Parent.ComponentDesc)
local WSAssert = require(script.Parent.WSAssert)

local SERVER = RunService:IsServer() and not RunService:IsClient()

local EntityReplicator = {}

-- Internal
------------------------------------------------------------------------------------------------------------------------------
local Remotes
local RemoteEvent
local RemoteFunction
local FreedNetworkIds
local PlayerReferences
local PlayerBuffers

local NumNetworkIds = 0
local NetworkIdsByInstance = {}
local InstancesByNetworkId = {}
local ClientSerializableParams = {}
local BitsSetTable = {}

local bExtract = bit32.extract
local bReplace = bit32.replace
local blShift = bit32.lshift
local bOr = bit32.bor
local bAnd = bit32.band
local bNot = bit32.bnot

EntityReplicator._componentMap = nil
EntityReplicator._entityMap = nil
EntityReplicator.EntityManager = nil

-- Misc. helper functions
-----------------------------------------------------------------------------

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

-- sets the bit at position pos of n 
local function setBitAtPos(n, pos)
	local mask = blShift(1, pos)
	return bOr(bAnd(n, bNot(mask)), bAnd(blShift(pos), mask))
end

---Calculates next char for id string
-- gsub function for getIdStringFromNum
local __IdLen, __IdNum = 0, 0
local function calcIdString()
	return string.char(__IdNum - ((__IdLen- 1) * 256) - 1)
end

---Gets the id string of a positive integer num
-- !!! not thread safe !!!
-- @param num number 
local function getIdStringFromNum(num)
	__IdLen = math.ceil(num * .00390625) -- num / 256
	__IdNum = num
	return string.rep("_", __IdLen):gsub(".", calcIdString())
end

---Gets the number corresponding to an id string str
-- @param str string
local function getIdNumFromString(str)
	local id = 1
	for c in str:gmatch(".") do
		id = id + string.byte(c)
	end
	return id
end

-- Serialization functions
-----------------------------------------------------------------------------

---Serializes the creation or destruction of an entity
-- @param instance Instance to which the entity to be serialized is attached
-- @param networkId number signifying the networkId of this entity
-- @param entities table to which entity data is serialized
--
-- NOTE: a Vector2int16 actually contains 2 values of the type int16, but these may be treated as uint16 (two's complement)
--
-- table entities: 
--
--    { ..., Vector2int16[uint16 networkId, uint16 flags], Vector2int16[uint16 halfWord1, uint16 halfWord2], ...* } 
--    
--    *one additional Vector2int16 struct per non-zero componentId field word
--
-- uint16 flags:
--
--___15______14______13______12______11______10______9_______8_______7_______6_______5_______4_______3_______2_______1_______0
--   0	 |   0   |   0   |   0       0       0       0       0       0       0       0       0   |   0       0       0       0
--       |       |       |                                                                       |                            |
-- if set| if set| if set|                               numParams                               |     nonZeroBitFieldIndices |
-- update| isRef |destroy|                                                                       |                            |
------------------------------------------------------------------------------------------------------------------------------
--
--  [0, 3] : field representing indices of non-zero values of _entityMap[instance][0]
-- [4, 12] : 9-bit integer representing the total number of parameters on this entity [maximum 512 parameters per entity]
--     13  : bit representing whether this is a destruction message
--     14  : bit representing whether entity is referenced in the system
--     15  : bit representing whether this is an update message
------------------------------------------------------------------------------------------------------------------------------
-- @param params table to which parameter values are serialized
-- table params:
--
--    { ..., value, value, value, ...* } 
--    
--    *one additional value for each parameter on this entity
------------------------------------------------------------------------------------------------------------------------------
-- @param entitiesIndex number indicating current index of entities; initial value should be 1
-- @param paramsIndex number indicating current index of params; initial value should be 0
-- @param isDestruction boolean indicating whether this is a creation message or a destruction message
-- @param isReferenced boolean indicating whether this entity is referenced
-- @return entitiesIndex
-- @return paramsIndex
local function serializeNext(instance, networkId, entities, params, entitiesIndex, paramsIndex, isDestruction, isReferenced)
	local entityStruct = EntityReplicator._entityMap[instance]
	local bitFields = entityStruct[0]
	local flags = 0
	local numBitFields = 0
	local numParams = 0

	for offset, bitField in ipairs(bitFields) do
		if bitField ~= 0 then
			for pos = 0, 31 do
				if bAnd(bitField, pos) ~= 0 then
					numParams = 0
					-- array part of component struct must be contigous!
					for _, v in ipairs(EntityReplicator._componentMap[entityStruct[pos + ((offset - 1) * 32))] do
						paramsIndex = paramsIndex + 1
						numParams = numParams + 1
						params[paramsIndex] = v
					end
					-- set 5th through 13th bits to numParams 
					flags = bReplace(flags, 4, numParams, 9)
				end
			end

			-- set bit at offset (offset <= 4)
			flags = setBitAtPos(flags, offset - 1)

			-- increment numBitFields, entitiesIndex; set component word in entities at entitiesIndex
			entitiesIndex = entitiesIndex + 1
			numBitFields = numBitFields + 1
			entities[entitiesIndex] = Vector2int16.new(bExtract(bitField, 0, 16), bExtract(bitField, 16, 16))
		end
	end
	
	if isDestruction then
		flags = setBitAtPos(flags, 13)
		entities[entitiesIndex] = Vector2int16.new(networkId, flags)
		entitiesIndex = entitiesIndex + 1
		return entitiesIndex, paramsIndex
	end

	if isReferenced then
		flags = setBitAtPos(flags, 14)
	end

	entities[entitiesIndex - numBitFields] = Vector2int16.new(networkId, flags)
	entitiesIndex = entitiesIndex + 1
	
	return entitiesIndex, paramsIndex
end

---Serializes the changed parameters of components on the entity attached to instance
-- @param instance Instance to which this entity is attached
-- @param networkId number the networkId for this entity
-- @param entities table to which entity data is serialized
-- table entities:
--
--    { ..., Vector2int16[uint16 networkId, uint16 flags], 
--        Vector2int16[uint16 halfWord1, uint16 halfWord2], ...,* 
--        Vector2int16[uint16 paramField1, uint16 paramField2], ...**
--    } 
--    
--    * one (1) additional Vector2int16 struct per non-zero component word
--    ** one (1) additional Vector2int16 struct per two (2) changed components [max sixteen (16) parameters per component]

-- uint16 flags:

--___15______14______13______12______11______10______9_______8_______7_______6_______5_______4_______3_______2_______1_______0
--   0	 |   0       0       0       0       0       0       0       0       0       0       0   |   0       0       0       0
--       |                                                                                       |                            |
-- if set|                                        (unused)                                       |    nonZeroBitFieldIndices  |
-- update|                                                                                       |                            |
-------------------------------------------------------------------------------------------------------------------------------
--
--   [0, 3] : field representing indices of non-zero component fields
-- [4 , 14] : N/A
--      15  : bit representing whether this is an update message
------------------------------------------------------------------------------------------------------------------------------
-- @param params table to which parameter values are serialized
-- table params:
--
--    { ..., value, value, ...* }
--
--    * one (1) additional value per parameter
------------------------------------------------------------------------------------------------------------------------------
-- @param entitiesIndex number indicating the current index of entities
-- @param paramsIndex number indicating the current index of params
-- @param changedParamsMap table mapping component ids to changed parameter fields
local function serializeNextUpdate(instance, networkId, entities, params, entitiesIndex, paramsIndex, changedParamsMap)
	local entityStruct = EntityReplicator._entityMap[instance]
	local flags = 0
	local numDataStructs = 0
	local numParamStructs = 0	
	local numBitFields = 0
	local numComponents = 0
	local currentComponentId = 0
	local lastComponentId = 0
	local bitFields = {0, 0, 0, 0}

	for componentId, changedParams in pairs(changedParamsMap) do
		local offset = math.ceil(componentId * 0.03125) -- componentId / 32
		bitFields[offset] = setBitAtPos(bitFields[offset], componentId - 1 + (32 * (offset - 1)))
		numBitFields = offset
		flags = setBitAtPos(flags, offset - 1)
	end

	for offset, bitField in ipairs(bitFields) do
		local componentOffset = 32 * (offset - 1)
		if bitField ~= 0 then
			entitiesIndex = entitiesIndex + 1
			numDataStructs = numDataStructs + 1
			entitiesIndex[entitiesIndex] = Vector2int16.new(bExtract(bitField, 0, 16), bExtract(bitField, 16, 16))
			for pos = 0, 31 do
				if bAnd(bitField, pos) ~= 0 then
					numComponents = numComponents + 1
					currentComponentId = pos + 1 + componentOffset
					if bAnd(numComponents, 1) ~= 0 then
						numParamStructs = numParamStructs + 1
						numDataStructs = numDataStructs + 1
						numComponents = 0
						entities[entitiesIndex + numBitFields + numParamStructs] = Vector2int16.new(changedParamsMap[lastComponentId], changedParamsMap[currentComponentId])
						for paramId = 0, 15 do
							if bAnd(changedParamsMap[lastComponentId], paramId) ~= 0 then
								paramsIndex = paramsIndex + 1
								params[paramsIndex] = EntityReplicator._componentMap[lastComponentId][entityStruct[lastComponentId]][paramId + 1]
							end
						end
					else
						for paramId = 0, 15 do
							if bAnd(changedParamsMap[currentComponentId], paramId) ~= 0 then
								paramsIndex = paramsIndex + 1
								params[paramsIndex] = EntityReplicator._componentMap[currentComponentId][entityStruct[currentComponentId]][paramId + 1]
							end
						end
						lastComponentId = currentComponentId
					end
				end
			end
		end
	end

	flags = setBitAtPos(flags, 15)
	entities[entitiesIndex - numDataStructs] = Vector2int16.new(networkId, flags)
	entitiesIndex = entitiesIndex + 1
	
	return entitiesIndex, paramsIndex
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

-- Deserialization functions
-----------------------------------------------------------------------------

---Deserializes the next message in entities
-- @param entities table containing serial entity data
-- @param params table containing serial param data
-- @param entitiesIndex number indicating current index in entities
-- @param paramsIndex number indicating current index in params
-- @return networkId number
-- @return componentIdsToParams table
-- @return entitiesIndex number
-- @return paramsIndex number
-- @return isDestruction boolean
-- @return isReferenced boolean
local function deserializeNext(entities, params, entitiesIndex, paramsIndex)
	local networkIdDataObj = entities[entitiesIndex]
	local networkId = bOr(networkIdDataObj.X, 0) -- cast to unsigned
	local flags = networkIdDataObj.Y
	local numBitFields = 0
	local bitFieldOffsets = {}
	local componentIdsToParams = {}

	-- destruction msg
	if bAnd(flags, 14) ~= 0 then
		entitiesIndex = entitiesIndex + 1
		return networkId, nil, entitiesIndex, paramsIndex
	end

	for pos = 0, 3 do
		if bAnd(flags, pos) ~= 0 then
			numBitFields = numBitFields + 1
			bitFieldOffsets[numBitFields] = pos
		end
	end

	-- entity update
	if bAnd(flags, 15) ~= 0 then
		entitiesIndex = entitiesIndex + 1

		local dataObj = entities[entitiesIndex]
		local bitField = bReplace(dataObj.X, dataObj.Y, 16, 16)
		local bitFieldOffset = bitFieldOffsets[1]
		local componentId = 0
		local numComponents = 0
		local index = ""

		for i = 1, numBitFields do
			for pos = 0, 31 do
				if bAnd(bitField, pos) ~= 0 then
					componentId = pos + 1 + (bitFieldOffset * 32)
					numComponents = numComponents + 1
					index = bAnd(numComponents, 1) == 0 and "Y" or "X"
					dataObj = entities[entitiesIndex + numBitFields - i + 1 + math.ceil(numComponents * 0.5)]
					bitField = dataObj[index]

					for paramId = 0, 15 do
						if bAnd(bitField, paramId) then
							paramsIndex = paramsIndex + 1
							componentIdsToParams[componentId][paramId + 1] = params[paramsIndex]
						end
					end
				end
			end

			if i + 1 < numBitFields then
				entitiesIndex = entitiesIndex + 1
				dataObj = entities[entitiesIndex]
				bitField = bReplace(dataObj.X, dataObj.Y, 16, 16)
				bitFieldOffset = bitFieldOffsets[i + 1]
			else
				break
			end
		end
		
		entitiesIndex = entitiesIndex + 1
		return networkId, componentIdsToParams, entitiesIndex, paramsIndex, nil, true
	end
		
	entitiesIndex = entitiesIndex = 1

	local dataObj = entities[entitiesIndex]
	local bitField = bReplace(dataObj.X, dataObj.Y, 16, 16)
	local bitFieldOffset = bitFieldOffsets[1]
	local componentId = 0

	for i = 1, numBitFields do
	
		for pos = 0, 31 do
			if bAnd(bitField, pos) ~= 0 then
				componentId = pos + 1 + (bitFieldOffset * 32)
				componentIdsToParams[componentId] = {}
				for i = 1, bExtract(flags, 4, 9) do
					paramsIndex = paramsIndex + 1
					componentIdsToParams[componentId][i] = params[paramsIndex]
				end
			end
		end

		if i + 1 < numBitFields then
			entitiesIndex = entitiesIndex + 1
			dataObj = entities[entitiesIndex]
			bitField = bReplace(dataObj.X, dataObj.Y), 16, 16)
			bitFieldOffset = bitFieldOffsets[i + 1]
		else
			break
		end
	end

	entitiesIndex = entitiesIndex + 1
	return networkId, componentIdsToParams, entitiesIndex, paramsIndex, bAnd(flags, 14) ~= 0
end

---Deserializes the 
local function deserializePrefab(entitiesFolder, entities, ...)
	for _, v in ipairs(entitiesFolder:GetChildren()) do
		local entitiesIndex = 1
		local paramsIndex = 0
		local params =  { ... }
		local networkId, componentIdsToParams, isReferenced
		
		networkId, componentIdsToParams, entitiesIndex, paramsIndex, isReferenced = deserializeNext(entities, params, entitiesIndex, paramsIndex)

		local instance = entitiesFolder[getIdStringFromNum(networkId)]
		instance.Name = "__WSEntity"
		
		if isReferenced then
			NetworkIdsByInstance[instance] = networkId
			InstancesByNetworkId[networkId] = instance
		end
		
		for componentId, params in pairs(componentIdsToParams) do
			EntityReplicator.EntityManager.AddComponent(instance, ComponentDesc.GetComponentTypeFromId(componentId), params)
		end
	end
end

-- Serverside functions for sending information to players
-----------------------------------------------------------------------------

---Queues a construction message in player's buffer for the networked entity with networkId associated with instance 
-- !!! not thread safe !!!
-- @param player Player
-- @param instance Instance
-- @param networkId number
local function sendConstructionTo(player, instance, networkId)
	local playerBuffer = PlayerBuffers[player]
	local entitiesIndex, paramsIndex = serializeNextEntity(instance, networkId, playerBuffer[1], playerBuffer[2], playerBuffer[3], playerBuffer[4])
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
	local entitiesIndex, paramsIndex = serializeNextEntity(instance, networkId, playerBuffer[1], playerBuffer[2], playerBuffer[3], playerBuffer[4], true, true)
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

-- Clientside functions for sending information to server
-----------------------------------------------------------------------------

local function doSendComponent(networkId, componentId)
end

local function doSendComponentUpdate(networkId, componentId, changeParamsMap)
end

-- Serverside functions for constructing and destructing player replicators
-----------------------------------------------------------------------------

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

function EntityReplicator.ReferenceForPlayer(player, instance, sendConstructionMessage)
	local networkId = NetworkIdsbyInstance[instance] or getNetworkId(instance)
	PlayerReferences[player][instance] = true
	if sendConstructionMessage then
		sendConstruction(player, instance, networkId)
	end
end

function EntityReplicator.DereferenceForPlayer(player, instance, sendDestructionMessage)
	PlayerReferences[player][instance] = nil
	if sendDestructionMessage then
		sendDestruction(player, instance, networkId)
	end
end

function EntityReplicator.Reference(instance, sendConstructionMessage)
	local networkId = NetworkIdsByInstance[instance] or getNetworkId(instance)
	for player, references in pairs(PlayerReferences) do
		references[instance] = true
		if sendConstructionMessage then
			sendConstruction(player, instance, networkId)
		end
	end
end

function EntityReplicator.Dereference(instance, sendDestructionMessage)
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

function EntityReplicator.Unique(player, instance)
	local entities = {}
	local params = {}
	local entitiesIndex = 1
	local paramsIndex = 0
	local ref = NetworkIdsByInstance[instance]
	local networkId = ref or 1
	entities, params = serializeNextEntity(instance, networkId, entities, params, entitiesIndex, paramsIndex, nil, ref and true or nil)
	doSendUnique(player, instance, entities, params)
end

function EntityReplicator.FromPrefab(player, rootInstance)
	local entities, params = serializePrefabFor(player, rootInstance)
	coroutine.resume(coroutine.create(pcall, doSendPrefab, player, rootInstance, entities, params, false))
end

function EntityReplicator.UniqueFromPrefab(player, rootInstance)
	local entities, params = serializePrefabFor(player, rootInstance)
	coroutine.resume(coroutine.create(pcall, doSendPrefab, player, rootInstance, entities, params, true))
end

function EntityReplicator.SetClientSerializable(componentType, paramName)
	WSAssert(SERVER)
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local paramId = paramName and ComponentDesc.GetParamIdFromName(componentId, paramName)
	setSerializationBehavior(true, componentId, paramName)
end

function EntityReplicator.SetClientCreatable(componentType, paramName)
end

function EntityReplicator.Step()
end

if SERVER then
	PrefabEntities = {}

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
					static[1], static[2], static[3], static[4] = serializeNextEntity(instance, id, static[1], static[2], static[3], static[4])
				end

				instance.Name = name
				instance.Parent = rootInstance.__WSEntities
			end
		end
	end

	Remotes = {}
	FreedNetworkIds = {}
	PlayerReferences = {}
	PlayerBuffers = {}

	Players.PlayerAdded:Connect(newPlayerReplicator)
	Players.PlayerRemoving:Connect(destroyPlayerReplicator)

	for _, player in ipairs(Players:GetPlayers()) do
		newReplicatorFor(player)
	end
else
	RemoteEvent = Players.LocalPlayer.PlayerGui:WaitForChild("RemoteEvent")
	RemoteFunction = Players.LocalPlayer.PlayerGui:WaitForChild("RemoteFunction")

	RemoteEvent.OnServerEvent:Connect(function()
	end)

	local function onServerInvoke(rootInstance, entitiesStruct, ...)
		local prefab = rootInstance:FindFirstChild("__WSEntities")
		if prefab then
			if rootInstance.Parent == Players.LocalPlayer.PlayerGui then
				rootInstance = rootInstance:Clone()
				rootInstance.Parent = Workspace
			end
			deserializePrefab(rootInstance.__WSEntities, entitiesStruct, ...)
		else
			deserializeUnique(rootInstance, entitiesStruct, ...)
		end
	end

	RemoteFunction.OnServerInvoke = function(rootInstance, entitiesStruct, ...)
		coroutine.resume(coroutine.create(onServerInvoke, rootInstance, entitiesStruct, ...))
	end)
end

return EntityReplicator

