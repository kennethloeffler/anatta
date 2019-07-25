-- EntityReplicator.lua (experimental)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ComponentDesc = require(script.Parent.ComponentDesc)
local WSAssert = require(script.Parent.WSAssert)

local SERVER = RunService:IsServer() and not RunService:IsClient()

local EntityReplicator = {}

local Remotes
local RemoteEvent
local RemoteFunction
local FreedNetworkIds
local PlayerEntityReferences
local PlayerUpdateQueues
local NumNetworkIds = 0
local NetworkIdsByInstance = {}
local InstancesByNetworkId = {}
local ClientSerializableParams = {}

local bExtract = bit32.extract
local bReplace = bit32.replace

EntityReplicator._componentMap = nil
EntityReplicator._entityMap = nil
EntityReplicator.EntityManager = nil

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
	return networkId
end

local function serializeEntityWithNetworkId(instance, networkId)
	local entityStruct = EntityReplicator._entityMap[instance]
	local bitFields = entityStruct[0]
	local serialEntityStruct = {true}
	local paramStruct = {}
	local fieldFlags = 0

	for i, bitField in ipairs(bitFields) do
		if bitField ~= 0 then
			bReplace(fieldFlags, i, 1)
			serialEntityStruct[#serialEntityStruct + 1] = Vector2int16.new(bExtract(bitField, 0, 16), bExtract(bitField, 15, 16))
		end
	end

	serialEntityStruct[1] = Vector2int16.new(networkId, fieldFlags)

	for componentId, offset in pairs(entityStruct) do
		if componentId ~= 0 then
			local componentParams = EntityReplicator._componentMap[offset]
			-- array part of component struct must must be contigous!
			for i, v in ipairs(componentParams)
				paramStruct[#paramStruct + 1] = v
			end
			paramStruct[#paramStruct + 1] = false
		end
	end
	return componentStruct, paramStruct
end

local function deserializeEntity(instance)
	-- cast to number
	local networkId = instance.Name - 0
end

function EntityReplicator.Reference(player, instance)

end

function EntityReplicator.Dereference(player, instance)
	
end

function EntityReplicator.UniqueFromPrefab(player, rootInstance)
	WSAssert(RootInstance[rootInstance], "%s is not a prefab", rootInstance.Name)
	
	coroutine.create(coroutine.resume(function()
		local clone = instance:Clone()
		for _, entity in ipairs(instance._WSEntities:GetChildren()) do
			
		end
		clone.Parent = player.PlayerGui
		-- yield until client acknowledges the instance
		pcall(function() Remotes[player][2]:InvokeClient(player, instance, PrefabRootInstances[instance]) end)
		clone:Destroy()
	end))
end

function EntityReplicator.AddToPrefab(rootInstance)
end

function EntityReplicator.ServerCreatedClientSerializable(componentType, paramName)
	WSAssert(SERVER)
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)
	local paramId = paramName and ComponentDesc.GetParamIdFromName(componentId, paramName)
	setSerializationBehavior(true, componentId, paramName)
end

function EntityReplicator.ServerCreatedServerSerializable(componentType)
	WSAssert(SERVER)
	local componentId = ComponentDesc.GetComponentIdFromType(componentType)	
	setSerializationBehavior(false, componentId, paramName)
end

function EntityReplicator.Step()
end

local function newReplicatorFor(player)
	-- probably unnecessary for each client to have its own private remote pair... but why not?
	WSAssert(SERVER)
	local remoteEvent = Instance.new("RemoteEvent")
	local remoteFunction = Instance.new("RemoteFunction")

	Remotes[player] = {remoteEvent, remoteFunction}
	PlayerReferences[player] = {}
	PlayerQueues[player] = {}

	remoteEvent.Parent = player.PlayerGui
	remoteFunction.Parent = player.PlayerGui

	remoteFunction.OnClientInvoke:Connect(function(player)
	end)

	remoteEvent.OnClientEvent:Connect(function(player)
	end)
end

local function destroyPlayerReplicatorFor(player)
	WSAssert(SERVER)
	Remotes[player][1]:Destroy()
	Remotes[player][1]:Destroy()
	Remotes[player] = nil
	PlayerReferences[player] = {}
	PlayerQueues[player] = nil
end

if SERVER then
	local RootInstances = CollectionService:GetTagged("__WSReplicatorRootInstance")
	local Entities = CollectionService:GetTagged("__WSEntity")
	
	for _, rootInstance in pairs(RootInstances) do
		local entitiesFolder = Instance.new("Folder")
		entitiesFolder.Name = "__WSEntities"
		entitiesFolder.Parent = rootInstance
	end

	for _, instance in pairs(Entities) do
		for _, rootInstance in pairs(RootInstances) do
			if instance:IsDescendantOf(rootInstance) then
				instance.Parent = rootInstance._WSEntities
			end
		end
	end

	Remotes = {}
	FreedNetworkIds = {}
	PlayerReferences = {}
	PlayerQueues = {}

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

	RemoteFunction.OnServerInvoke:Connect(function()
	end)
end

return EntityReplicator

