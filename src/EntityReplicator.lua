-- EntityReplicator.lua (experimental)
-- This module is one giant hack. Be careful please

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ComponentDesc = require(script.Parent.ComponentDesc)
local WSAssert = require(script.Parent.WSAssert)

local SERVER = RunService:IsServer() and not RunService:IsClient()

local EntityReplicator = {}

-- Internal
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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

local bExtract = bit32.extract
local bReplace = bit32.replace

EntityReplicator._componentMap = nil
EntityReplicator._entityMap = nil
EntityReplicator.EntityManager = nil

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

---Calculates next char for id string
local __IdLen, __IdNum = 0, 0
local function calcIdString()
	return string.char(__IdNum - ((len - 1) * 256) - 1)
end

---Gets the id string of a positive integer num
-- WARNING: for use on client ONLY
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

---Serializes the entity data attached to instance
-- entities table spec: 
--	{ Vector2int16(uint16 networkId, uint16 flags), Vector2int16(uint16 halfWord1, uint16 halfWord2), ... } (one additional Vector2int16 per non-zero component word)
-- flags spec:
--	15______14______13______12______11______10______9_______8_______7_______6_______5_______4_______3_______2_______1_______0
--	0	    0   |   0   |   0   |   0       0       0       0       0       0       0       0   |   0       0       0       0
--              |       |       |                                                               |                            |
--      N/A     |if set,|if set,|                           numParams                           |   nonZeroBitFieldIndices   |
--              |destroy| isRef |                                                               |                            |
------------------------------------------------------------------------------------------------------------------------------
-- @param instance Instance to which the entity to be serialized is attached
-- @param networkId number signifying the networkId of this entity
-- @param entities table to which entity data is serialized 
-- @param params table to which param data is serialized
-- @param entitiesIndex number indicatingcurrent index of entites
-- @param paramsIndex number indicating current index of params
-- @param isReferenced boolean indicating whether this entity is referenced
-- @return entitiesIndex
-- @return paramsIndex
local function serializeNextEntity(instance, networkId, entities, params, entitiesIndex, paramsIndex, isReferenced)
	local entityStruct = EntityReplicator._entityMap[instance]
	local bitFields = entityStruct[0]
	local flags = 0
	local numBitFields = 0
	local numParams = 0

	for i, bitField in ipairs(bitFields) do
		if bitField ~= 0 then
			entitiesIndex = entitiesIndex + 1
			numBitFields = numBitFields + 1
			flags = bReplace(flags, i - 1, 1)
			entities[entitiesIndex] = Vector2int16.new(bExtract(bitField, 0, 16), bExtract(bitField, 16, 16))

			for offset = 1, 32 do
				if bExtract(bitField, offset - 1) == 1 then
					numParams = 0
					-- array part of component struct must be contigous!
					for _, v in ipairs(EntityReplicator._componentMap[entityStruct[offset + ((i - 1) * 32)]]) do
						paramsIndex = paramsIndex + 1
						numParams = numParams + 1
						params[paramsIndex] = v
					end
					flags = bReplace(flags, 4, numParams, 8)
				end
			end
		end
	end
	
	if isDestruction then
		entities[entitiesIndex] = Vector2int16.new(networkId, flags)
		flags = bReplace(flags, 12, 1)
		entitiesIndex = entitiesIndex + 1
		return entitiesIndex, paramsIndex
	end

	if isReferenced then
		flags = bReplace(flags, 13, 1)
	end

	entities[entitiesIndex - numBitFields] = Vector2int16.new(networkId, flags)
	entitiesIndex = entitiesIndex + 1
	
	return entitiesIndex, paramsIndex
end

---Deserializes the next entity in entities
-- @param entities table containing serial entity data
-- @param params table containing serial param data
-- @param entitiesIndex number indicating current index in entities
-- @param paramsIndex number indicating current index in params
-- @return networkId number
-- @return componentIdsToParams table
-- @return entitiesIndex number
-- @return paramsIndex number
-- @return isReferenced boolean
local function deserializeNextEntity(entities, params, entitiesIndex, paramsIndex)
	local networkIdDataObj = entities[entitiesIndex]
	local networkId = networkIdDataObj.X
	local flags = networkIdDataObj.Y
	local numParams = bExtract(flags, 4, 8)
	local numBitFields = 0
	local bitFieldOffsets = {}
	local componentIdsToParams = {}

	-- destruction msg
	if bExtract(flags, 12) == 1 then
		entitiesIndex = entitiesIndex + 1
		return networkId, nil, entitiesIndex, paramsIndex
	end

	for offset = 1, 4 do
		if bExtract(flags, offset - 1) == 1 then
			numBitFields = numBitFields + 1
			bitFieldOffsets[numBitFieldOffsets] = offset - 1
		end
	end

	for i = 1, numBitFields do
		entitiesIndex = entitiesIndex = 1
		local dataObj = entities[entitiesIndex]
		local firstField = dataObj.X
		local secondField = dataObj.Y
		local bitFieldOffset = bitFieldOffsets[i]
		
		for offset = 1, 32 do
			local componentId
			if offset <= 16 then
				if bExtract(firstField, offset - 1) == 1 then
					componentId = offset + (32 * bitFieldOffset)
				end
			else
				if bExtract(secondField, offset - 17) == 1 then
					componentId = offset + (32 * bitFieldOffset)
				end
			end
			if componentId then
				componentIdsToParams[componentId] = {}
				for i = 1, numParams do
					paramsIndex = paramsIndex + 1
					componentIdsToParams[componentId][i] = params[paramsIndex]
				end
			end
		end
	end

	entitiesIndex = entitiesIndex + 1
	return networkId, componentIdsToParams, entitiesIndex, paramsIndex, bExtract(flags, 13) == 1
end

local function sendConstruction(player, instance, networkId)
	local playerBuffer = PlayerBuffers[player]
	local entitiesIndex, paramsIndex = serializeNextEntity(instance, networkId, playerBuffer[1], playerBuffer[2], playerBuffer[3], playerBuffer[4])
	playerBuffer[3] = entitiesIndex
	playerBuffer[4] = paramsIndex
end

local function sendDestruction(player, instance, networkId)
	local playerBuffer = PlayerBuffers[player]
	local entitiesIndex, paramsIndex = serializeNextEntity(instance, networkId, playerBuffer[1], playerBuffer[2], playerBuffer[3], playerBuffer[4], true)
	playerBuffer[3] = entititesIndex
	playerBuffer[4] = paramsIndex
end

local function serializePrefab(prefabRootInstance, player)
	local rootClone = prefabRootInstance:Clone()
	local entities = {}
	local params = {}
	local entitiesIndex = 1
	local paramsIndex = 0
	for _, instance in ipairs(prefabRootInstance.__WSEntities:GetChildren()) do
		local reference = NetworkIdsByInstance[instance]
		local networkId = reference and reference or getIdNumFromString(instance.Name) 
		
		entitiesIndex, paramsIndex = serializeNextEntity(instance, networkId, entities, params, entitiesIndex, paramsIndex, reference and true or false)
		
		if reference then
			EntityReplicator.ReferenceForPlayer(player, instance)
		end
	end
	return rootClone, entities, params
end

local function deserializePrefab(entitiesFolder, entities, params)
	for _, v in ipairs(entitiesFolder:GetChildren()) do
		local entitiesIndex = 1
		local paramsIndex = 0
		local networkId, componentIdsToParams, temp
		
		networkId, componentIdsToParams, entitiesIndex, paramsIndex, isReferenced = deserializeNextEntity(entities, params, entitiesIndex, paramsIndex)

		local instance = entitiesFolder[getIdStringFromNum(networkId)]
		
		if isReferenced then
			NetworkIdsByInstance[instance] = networkId
			InstancesByNetworkId[networkId] = instance
		end
		
		for componentId, params in pairs(componentIdsToParams) do
			EntityReplicator.EntityManager.AddComponent(instance, ComponentDesc.GetComponentTypeFromId(componentId), params)
		end
	end
end

local function newReplicatorFor(player)
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

local function destroyPlayerReplicatorFor(player)
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

function EntityReplicator.UniqueFromPrefab(player, rootInstance)
	WSAssert(RootInstance[rootInstance], "%s is not a prefab", rootInstance.Name)
	WSAssert(SERVER)
	coroutine.create(coroutine.resume(function()
		local clone, entitiesStruct, paramsStruct = serializePrefab(rootInstance, player)  
		clone.Parent = player.PlayerGui
		-- yield until client acknowledges or invocation fails
		pcall(function() Remotes[player][2]:InvokeClient(player, clone, entitiesStruct, paramsStruct) end)
		clone:Destroy()
	end))
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

-- initialization
if SERVER then
	local RootInstances = CollectionService:GetTagged("__WSReplicatorRootInstance")
	local Entities = CollectionService:GetTagged("__WSEntity")
	local RootInstanceEntities = {}

	for _, rootInstance in pairs(RootInstances) do
		local entitiesFolder = Instance.new("Folder")
		entitiesFolder.Name = "__WSEntities"
		entitiesFolder.Parent = rootInstance
		RootInstanceEntitiesNum[rootInstance] = 0
	end

	for _, instance in pairs(Entities) do
		for _, rootInstance in pairs(RootInstances) do
			if instance:IsDescendantOf(rootInstance) then
				local name
				if instance:HasTag("__WSReplicatorRef")
					name = getNetworkId(instance)
				else
					RootInstanceEntitiesNum[rootInstance] = RootInstanceEntitiesNum[rootInstance] + 1
					local tempId = getTempIdString(RootInstanceEntitiesNum[rootInstance])
					local tonum = tonum(tempId)
					name = tempId
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

	Players.PlayerAdded:Connect(function(player)
		newReplicatorFor(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		destroyReplicatorFor(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		newReplicatorFor(player)
	end
else
	RemoteEvent = Players.LocalPlayer.PlayerGui:WaitForChild("RemoteEvent")
	RemoteFunction = Players.LocalPlayer.PlayerGui:WaitForChild("RemoteFunction")

	RemoteEvent.OnServerEvent:Connect(function()
	end)

	RemoteFunction.OnServerInvoke = function(rootInstance, entitiesStruct, paramsStruct)
		local prefab = rootInstance:FindFirstChild("__WSEntities")
		if prefab then
			deserializePrefab(prefab, entitiesStruct, paramsStruct)
			rootInstance.Parent = workspace
		else
			deserializeUnique(rootInstance, entitiesStruct, paramsStruct)
		end
		return
	end)
end

return EntityReplicator

