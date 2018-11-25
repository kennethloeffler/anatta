function TriggerSystem(EntityManager)
	
	function setupTouchTrigger(trigger)
		trigger.Parent.LocalSimulationTouched:connect(function(part)
			if part.Parent == game.Players.LocalPlayer.Character and trigger.Enabled then
				trigger.Enabled = false
				EntityManager:AddComponent(trigger.Parent, "_trigger", {Player = 0})
				wait(trigger.Debounce)
				trigger.Enabled = true
			end
		end)
	end
	
	local triggers = EntityManager:GetAllComponentsOfType("TouchTrigger")
	for _, trigger in pairs(triggers) do
		setupTouchTrigger(trigger)
	end
	
	EntityManager:GetComponentAddedSignal("TouchTrigger"):connect(function(entity)
		local trigger = EntityManager:GetComponent(entity, "TouchTrigger")
		setupTouchTrigger(trigger)
	end)
	
end

return TriggerSystem
