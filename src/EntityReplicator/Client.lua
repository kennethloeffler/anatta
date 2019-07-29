local ComponentDesc = require(script.Parent.Parent.ComponentDesc)
local Shared = require(script.Parent.Shared)

local NetworkIdsByInstance = {}
local InstancesByNetworkId = {}

local deserializeNext = Shared.DeserializeNext

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
			Client.EntityManager.AddComponent(instance, ComponentDesc.GetComponentTypeFromId(componentId), params)
		end
	end
end

local function doSendComponent(networkId, componentId)
end

local function doSendComponentUpdate(networkId, componentId, changeParamsMap)
end

function Client.Init(entityManager, entityMap, componentMap)
	RemoteEvent = Players.LocalPlayer.PlayerGui:WaitForChild("RemoteEvent")
	RemoteFunction = Players.LocalPlayer.PlayerGui:WaitForChild("RemoteFunction")

	Client.EntityManager = entityManager
	Client._entityMap = entityMap
	Client._componentMap = componentMap

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

return Client
