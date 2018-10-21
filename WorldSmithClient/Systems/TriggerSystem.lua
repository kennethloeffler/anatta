local CollectionService = game:GetService("CollectionService")
local Utilities = require(script.Parent.Parent.WorldSmithClientUtilities)
local TriggerSystem = {}

function TriggerSystem.Start(componentEntityMap)
	
	local function initializeTrigger(component)
		if component.Name == "TouchTrigger" then
			if component.Parent:IsA("BasePart") then
				component.Parent.Touched:connect(function(part)
					if component.Enabled.Value == true and part.Parent == game.Players.LocalPlayer.Character then
						component.Event:Fire(part)
					end
				end)
			end
		end
	end
	
	if componentEntityMap.TouchTrigger then
		for _, component in ipairs(componentEntityMap.TouchTrigger) do
			initializeTrigger(component)
		end
	end
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		Utilities.YieldUntilComponentLoaded(component)
		initializeTrigger(component)
	end)
	
end

return TriggerSystem
