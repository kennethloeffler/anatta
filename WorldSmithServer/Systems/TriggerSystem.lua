local CollectionService = game:GetService("CollectionService")

local TriggerSystem = {}

function TriggerSystem.Start(componentEntityMap)
	
	local function initializeTrigger(component)
		if component.Name == "TouchTrigger" then
			local bindableEvent = Instance.new("BindableEvent")
			bindableEvent.Parent = component
			if component.Parent:IsA("BasePart") then
				component.Parent.Touched:connect(function(part)
					if component.Enabled.Value == true then
						component.Event:Fire(part)
					end
				end)
			end
		elseif component.Name == "ContextActionTrigger" then
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Parent = component
			local bindableEvent = Instance.new("BindableEvent")
			bindableEvent.Parent = component
		end
	end
	
	if componentEntityMap.TouchTrigger then
		for _, component in ipairs(componentEntityMap.TouchTrigger) do
			initializeTrigger(component)
		end
	end
	
	if componentEntityMap.ContextActionTrigger then	
		for _, component in ipairs(componentEntityMap.ContextActionTrigger) do
			initializeTrigger(component)
		end
	end
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		initializeTrigger(component)
	end)
	
end

return TriggerSystem
