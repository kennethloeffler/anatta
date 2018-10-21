local CollectionService = game:GetService("CollectionService")
local WorldSmithUtilities = require(script.Parent.Parent.WorldSmithServerUtilities)

local DoorSystem = {}

function DoorSystem.Start(componentEntityMap) 
	
	local function animateDoor(component, dir, remoteEvent, player)
		if component.Enabled.Value == true then
			remoteEvent:FireAllClients(player, dir)
		end
	end
	
	local function initalizeDoor(component)
		if component.Name == "AnimatedDoor" then
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Parent = component
			local frontDirection = component.OpenDirection.Value == 0 and 1 or component.OpenDirection.Value
			local backDirection = component.OpenDirection.Value == 0 and -1 or component.OpenDirection.Value
			local frontEventObj, frontEventName = WorldSmithUtilities.GetTriggerEventNames(component.FrontTrigger.Value)
			component.FrontTrigger.Value[frontEventObj][frontEventName]:connect(function(part)
				local player = game.Players:GetPlayerFromCharacter(part.Parent)
				if part.Parent:FindFirstChild("Humanoid") or part:IsA("Player") then
					animateDoor(component, frontDirection, remoteEvent, player)
				end
			end)
			local backEventObj, backEventName = WorldSmithUtilities.GetTriggerEventNames(component.BackTrigger.Value)
			component.BackTrigger.Value[backEventObj][backEventName]:connect(function(part)
				local player = game.Players:GetPlayerFromCharacter(part.Parent) or part
				if part.Parent:FindFirstChild("Humanoid") or part:IsA("Player") then
					animateDoor(component, backDirection, remoteEvent, player)
				end
			end)	
		end
	end
	
	if componentEntityMap.AnimatedDoor then
		for _, component in ipairs(componentEntityMap.AnimatedDoor) do
			initalizeDoor(component)
		end
	end
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		initalizeDoor(component)
	end)
	
end

return DoorSystem
