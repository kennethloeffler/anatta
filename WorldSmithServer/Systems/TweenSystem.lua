local CollectionService = game:GetService("CollectionService")

local TweenSystem = {}

function TweenSystem.Start(componentEntityMap)
	
	local function initializeTween(component)
		if component.Name == "TweenPartPosition" or component.Name == "TweenPartRotation" then
			local remoteEvent = Instance.new("RemoteEvent", component)
			if component.Trigger.Value then
				if not component.ClientSide.Value then
					local timeToWait = component.RepeatCount.Value >= 0 and (component.Time.Value + (component.Reverses.Value and component.Time.Value or 0) + (component.RepeatCount.Value * component.Time.Value) + component.DelayTime.Value) or "n/a"
					if component.Trigger.Value:FindFirstChild("RemoteEvent") then
						component.Trigger.Value.RemoteEvent.OnServerEvent:connect(function()
							if component.Enabled.Value then
								component.Enabled.Value = false
								component.RemoteEvent:FireAllClients()
								if timeToWait ~= "n/a" then
									wait(timeToWait)
								end
								component.Enabled.Value = true
							end
						end)
					end
					if component.Trigger.Value:FindFirstChild("Event") then
						component.Trigger.Value.Event.Event:connect(function()
							if component.Enabled.Value then
								component.Enabled.Value = false
								component.RemoteEvent:FireAllClients()
								if timeToWait ~= "n/a" then
									wait(timeToWait)
								end
								component.Enabled.Value = true
							end
						end)
					end
				end
			end
		end
	end
	
	if componentEntityMap.TweenPartPosition then
		for _, component in ipairs(componentEntityMap.TweenPartPosition) do
			initializeTween(component)
		end
	end
	
	if componentEntityMap.TweenPartRotation then
		for _, component in ipairs(componentEntityMap.TweenPartRotation) do
			initializeTween(component)
		end
	end
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		initializeTween(component)
	end)
	
end

return TweenSystem
