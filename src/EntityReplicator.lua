-- EntityReplicator.lua
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
local Vector2int16Pool = {}

local bExtract = bit32.extract

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

local function serializeEntityWithNetworkId(instance, networkId, prefabEntityId)
	local entityStruct = EntityReplicator._entityMap[instance]
	local componentBitFields = entityStruct[0]
	local numComponents = 0
	local serialEntityStruct = {}
	local paramStruct = {}
	local index = 1
	
	serialEntityStruct[1] = Vector2int16.new(networkId, prefabEntityId)
	serialEntityStruct[2] = Vector2int16.new(bExtract(entityStruct[0][1], 0, 16), bExtract(entityStruct[0][1], 15, 16))
	serialEntityStruct[3] = Vector2int16.new(bExtract(entityStruct[0][2], 0, 16), bExtract(entityStruct[0][2], 15, 16))
	serialEntityStruct[4] = Vector2int16.new(bExtract(entityStruct[0][3], 0, 16), bExtract(entityStruct[0][3], 15, 16))
	serialEntityStruct[5] = Vector2int16.new(bExtract(entityStruct[0][4], 0, 16), bExtract(entityStruct[0][4], 15, 16))

	for componentId, offset in pairs(entityStruct) do
		if componentId ~= 0 then
			local componentParams = EntityReplicator._componentMap[offset]
			paramStruct[index] = {}
			-- array part of component struct must must be contigous!
			for i, v in ipairs(componentParams)
				paramStruct[index][i] = v
			end
		end
	end
	return componentStruct, paramStruct
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

