local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer() and not RunService:IsClient()

local EntityReplicator = {}
EntityReplicator.__index = EntityReplicator

function EntityReplicator.new(player)
	local instance = {}
	local PlayerGui = player:WaitForChild("PlayerGui")
	local RemoteFunction
	local RemoteEvent
	if IsServer then
		RemoteFunction = Instance.new("RemoteFunction")
		RemoteFunction.Parent = PlayerGui
	
		RemoteEvent = Instance.new("RemoteEvent")
		RemoteEvent.Parent = PlayerGui
		
		instance._replicatedEntitiesById = {}
	else
		RemoteFunction = PlayerGui:WaitForChild("RemoteFunction")
		RemoteEvent = PlayerGui:WaitForChild("RemoteEvent")
	end
	instance.Player = player
	instance._remoteFunction = RemoteFunction
	instance._remoteEvent = RemoteEvent
	return setmetatable(instance, EntityReplicator) 
end

function EntityReplicator:Reference(entity)
end

function EntityReplicator:Step()	
end

function EntityReplicator:Destroy()
end

return EntityReplicator
