local Workspace = game:GetService("Workspace")

local ComponentDesc = require(script.Parent.Parent.ComponentDesc)
local Constants = require(script.Parent.Constants)
local Shared = require(script.Parent.Shared)

local Client = {}

local SendBuffer = {}

local Queued = Shared.Queued
local DeserializeNext = Shared.DeserializeNext
local GetIdStringFromNum = Shared.GetIdStringFromNum

local RemoteEvent
local RemoteFunction

local function deserializePrefab(rootInstance, entities, ...)
	local entitiesIndex = 1
	local paramsIndex = 1
	local params = table.pack(...)

	for _ in next, entities do
		entitiesIndex, paramsIndex = DeserializeNext(entities, params, entitiesIndex, paramsIndex, rootInstance)
	end

	rootInstance.Parent = Workspace
end

local function deserializeUnique(rootInstance, entities, ...)
	local entitiesIndex = 1
	local paramsIndex = 1
	local params = table.pack(...)

	for _ in next, entities do
		entitiesIndex, paramsIndex = DeserializeNext(entities, params, entitiesIndex, paramsIndex, rootInstance)
	end

	rootInstance.Parent = Workspace
end

function Client.SendAddComponent(component)
	QueueUpdate(instance, ADD_COMPONENT, component._componentId)
end

function Client.SendParameterUpdate(component, paramName)
	QueueUpdate(instance, PARAMS_UPATE, component._componentId, GetParamIdFromName(paramsName))
end

function Client.Step()
	if next(Queued) then
		local entities = SendBuffer[1]
		local params = SendBuffer[2]
		local entitiesIndex = 1
		local paramsIndex = 1

		for instance, msgMap in pairs(Queued) do
			paramsIndex, entitiesIndex = SerializeNext(
				entities, params,
				entitiesIndex, paramsIndex,
				msgMap
			)

			Queued[instance] = nil
		end

		RemoteEvent:FireServer(entities, table.unpack(params))

		for i in ipairs(entities) do
			entities[i] = nil
		end

		for i in ipairs(params) do
			params[i] = nil
		end
	end
end

function Client.Init()
	RemoteEvent = Players.LocalPlayer.PlayerGui:WaitForChild("RemoteEvent")
	RemoteFunction = Players.LocalPlayer.PlayerGui:WaitForChild("RemoteFunction")

	RemoteEvent.OnServerEvent:Connect(function(rootInstance, entities, ...)
		local entitiesIndex = 1
		local paramsIndex = 1
		local params = table.pack(...)

		for _ in next, entities do
			entitiesIndex, paramsIndex = DeserializeNext(entities, params, entitiesIndex, paramsIndex, rootInstance)
		end
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

