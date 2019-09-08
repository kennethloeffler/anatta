local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ComponentDesc = require(script.Parent.Parent.ComponentDesc)
local Constants = require(script.Parent.Constants)
local PlayerGui = Player.LocalPlayer:WaitForChild("PlayerGui")
local Shared = require(script.Parent.Shared)

local Client = {}

local SendBuffer = {}

local Queued = Shared.Queued
local DeserializeNext = Shared.DeserializeNext
local SerializeUpdate = Shared.SerializeUpdate

local RemoteEvent
local RemoteFunction

local function deserializeEntities(rootInstance, isUnique, entities, ...)
	local entitiesIndex = 1
	local paramsIndex = 1
	local params = table.pack(...)

	for _ in next, entities do
		entitiesIndex, paramsIndex = DeserializeNext(entities, params, entitiesIndex, paramsIndex, rootInstance)
	end

	if isUnique then
		rootInstance.Parent = Workspace
	end
end

---Sends a message to the server requesting to add the component defined by component
-- component must be a component struct (i.e. the return value of EntityManager.GetComponent, etc.)
-- @param component

function Client.SendAddComponent(component)
	WSAssert(typeof(component) == "table" and component._componentId, "bad argument #1 (expected component struct)")

	QueueUpdate(instance, ADD_COMPONENT, component._componentId)
end

---Sends a message to the server requesting to set the parameter matching paramName to this client's current value
-- component must be a component struct (i.e. the return value of EntityManager.GetComponent, etc.)
-- @param component
-- @param paramName

function Client.SendParameterUpdate(component, paramName)
	WSAssert(typeof(component) == "table" and component._componentId, "bad argument #1 (expected component struct)")
	WSAssert(typeof(paramName) == "string", "bad argument #2 (expected string)")

	QueueUpdate(instance, PARAMS_UPATE, component._componentId, GetParamIdFromName(paramName))
end

---Steps this client's replicator

function Client.Step()
	if next(Queued) then
		local entities = SendBuffer[1]
		local params = SendBuffer[2]
		local entitiesIndex = 1
		local paramsIndex = 1

		for instance, msgMap in pairs(Queued) do
			paramsIndex, entitiesIndex = SerializeUpdate(
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

---Gets and initializes this client's remote objects

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
		local isUnique = rootInstance:IsDescendantOf(PlayerGui)

		rootInstance = isUnique and rootInstance:Clone() or rootInstance
		coroutine.wrap(deserializeEntities, rootInstance, isUnique, entitiesStruct, ...)()
	end

	RemoteFunction.OnServerInvoke = onServerInvoke
end

return Client

