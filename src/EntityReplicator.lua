-- EntityReplicator.lua
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WSAssert = require(script.Parent.WSAssert)

local SERVER = RunService:IsServer() and not RunService:IsClient()
local NUM_SENT_COMPONENTS_PER_NETWORK_STEP = 50

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
local Vector2int16Pool = {}

local b32Extract = bit32.extract

EntityReplicator._componentMap = nil
EntityReplicator._entityMap = nil

local function getNetworkId(instance)
	local networkId
	local numFreedNetworkIds = #FreedNetworkIds
	if numFreedNetworkIds > 0 then
		networkId = FreedNetworkIds[numFreedNetworkIds] 
		FreedNetworkIds[numFreedNetworkIds] = nil
	else
		networkId = NumNetworkIds + 1
	end
	InstancesByNetworkId[instance] = networkId
	return networkId
end

local function serializeEntity(instance)
	local entityStruct = EntityReplicator._entityMap[instance]
	local numComponents = 0
	local componentStruct = {}
	local paramStruct = {}
	entityStruct[1] = Vector2int.new()
	for bitFieldIndex, bitField in ipairs(entityStruct[0])
		local firstShort = b32Extract(bitField, 0, 16)
		local secondShort = b32Extract(bitField, 16, 16)
		componentStruct[#componentStruct + 1] = Vector2int16.new(firstShort, secondShort)
	end
	for componentId, offset in pairs(entityStruct) do
		if componentId ~= 0 then
			
		end
	end
end

function EntityReplicator.Reference(player, instance)

end

function EntityReplicator.Dereference(player, instance)
	
end

function EntityReplicator.UniqueFromPrefab(player, rootInstance)
	WSAssert(RootInstance[rootInstance], "%s is not a prefab", rootInstance.Name)
	
	coroutine.create(coroutine.resume(pcall(function()
		local clone = instance:Clone()
		clone.Parent = player.PlayerGui
		Remotes[player][2]:InvokeClient(player, instance, PrefabRootInstances[instance])
		clone:Destroy()
	end)))
end

function EntityReplicator.AddToPrefab(rootInstance)
end

function EntityReplicator.ClientSerializable(componentType, paramName)
	WSAssert(SERVER)
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
	Remotes[player[1]:Dertroy()
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
