local CollectionService = game:GetService("CollectionService")
local Utilities = require(script.Parent.Parent.WorldSmithClientUtilities)
local DoorSystem = {}

function DoorSystem.Start(componentEntityMap)
	
	local function AnimateDoor(component, dir)
		local cf1 = component.PivotPart.Value.CFrame * CFrame.Angles(0, dir * (math.pi / 2), 0)
		local tween1 = game:GetService("TweenService"):Create(
			component.PivotPart.Value,
			TweenInfo.new(component.Time.Value / 2, Enum.EasingStyle[component.EasingStyle.Value] or Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0),
			{CFrame = cf1}
		)
		tween1:Play()
		wait(component.Time.Value / 2)
		local cf2 = component.PivotPart.Value.CFrame * CFrame.Angles(0, dir * (-math.pi / 2), 0)
		local tween2 = game:GetService("TweenService"):Create(
			component.PivotPart.Value,
			TweenInfo.new(component.Time.Value / 2, Enum.EasingStyle[component.EasingStyle.Value] or Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, component.CloseDelay.Value or 0),
			{CFrame = cf2}
		)
		tween2:Play()
		wait((component.Time.Value / 2) + component.CloseDelay.Value)
	end
	
	local function initializeDoor(component)
		if component.Name == "AnimatedDoor" then
			--clientside prediction events
			component.FrontTrigger.Value.Event.Event:connect(function()
				if component.Enabled.Value == true then
					local direction = component.OpenDirection.Value == 0 and 1 or component.OpenDirection.Value
					component.Enabled.Value = false
					AnimateDoor(component, direction)
					component.Enabled.Value = true
				end
			end)
			component.BackTrigger.Value.Event.Event:connect(function()
				if component.Enabled.Value == true then
					local direction = component.OpenDirection.Value == 0 and -1 or component.OpenDirection.Value
					component.Enabled.Value = false
					AnimateDoor(component, direction)
					component.Enabled.Value = true
				end
			end)
			
			--server event
			component.RemoteEvent.OnClientEvent:connect(function(player, direction)
				if component.Enabled.Value == true and player ~= game.Players.LocalPlayer then
					component.Enabled.Value = false
					AnimateDoor(component, direction)
					component.Enabled.Value = true
				end
			end)
		end
	end
	
	if componentEntityMap.AnimatedDoor then
		for _, component in ipairs(componentEntityMap.AnimatedDoor) do
			initializeDoor(component)
		end
	end
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		Utilities.YieldUntilComponentLoaded(component)
		initializeDoor(component)
	end)
	
end

return DoorSystem
