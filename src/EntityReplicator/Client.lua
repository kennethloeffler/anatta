local Workspace = game:GetService("Workspace")

local ComponentDesc = require(script.Parent.Parent.ComponentDesc)
local Shared = require(script.Parent.Shared)

local Client = {}

local NetworkIdsByInstance = {}
local InstancesByNetworkId = {}
local EntityManager
local entityMap
local componentMap

local deserializeNext = Shared.DeserializeNext
local getIdStringFromNum = Shared.GetIdStringFromNum

---Deserializes the
local function deserializePrefab(rootInstance, entities, ...)
	for _, v in ipairs(rootInstance._s:GetChildren()) do
		local entitiesIndex = 1
		local paramsIndex = 0
		local params =  { ... }
		local networkId, componentIdsToParams, isReferenced

		networkId, componentIdsToParams, entitiesIndex, paramsIndex = deserializeNext(entities, params, entitiesIndex, paramsIndex)

		local instance = entitiesFolder[getIdStringFromNum(networkId)]
		instance.Name = "__WSEntity"

		for componentId, params in pairs(componentIdsToParams) do
			Client.EntityManager.AddComponent(instance, ComponentDesc.GetComponentTypeFromId(componentId), params)
		end
	end

	rootInstance.Parent = Workspace
end

function Client.Init(entityManager, entityMap, componentMap)
	RemoteEvent = Players.LocalPlayer.PlayerGui:WaitForChild("RemoteEvent")
	RemoteFunction = Players.LocalPlayer.PlayerGui:WaitForChild("RemoteFunction")

	Shared.Init(entityMap, componentMap)

	EntityManager = entityManager
	entityMap = entityMap
	componentMap = componentMap

	RemoteEvent.OnServerEvent:Connect(function()
	end)

	local function onServerInvoke(rootInstance, entitiesStruct, ...)
		local prefab = rootInstance:FindFirstChild("__WSEntities")

		if prefab then
			if rootInstance.Parent == Players.LocalPlayer.PlayerGui then
				rootInstance = rootInstance:Clone()
			end

			coroutine.resume(coroutine.create(deserializePrefab, rootInstance, entitiesStruct, ...))
		else
			rootInstance = rootInstance:Clone()
			coroutine.resume(coroutine.create(deserializeUnique, rootInstance, entitiesStruct, ...))
		end
	end

	RemoteFunction.OnServerInvoke = onServerInvoke
end

return Client
