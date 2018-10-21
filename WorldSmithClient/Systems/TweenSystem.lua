local CollectionService = game:GetService("CollectionService")
local Utilities = require(script.Parent.Parent.WorldSmithClientUtilities)

local TweenSystem = {}

function TweenSystem.Start(componentEntityMap)
	
	local function TweenPartPosition(component)
		local timeToWait = component.RepeatCount.Value >= 0 and (component.Time.Value + (component.Reverses.Value and component.Time.Value or 0) + (component.RepeatCount.Value * component.Time.Value) + component.DelayTime.Value) or "n/a"
		local cf = component.LocalCoords.Value and (component.Parent.CFrame * CFrame.new(component.X.Value, component.Y.Value, component.Z.Value)) or CFrame.new(component.X.Value, component.Y.Value, component.Z.Value)
		local tween = game:GetService("TweenService"):Create(
			component.Parent,
			TweenInfo.new(component.Time.Value, Enum.EasingStyle[component.EasingStyle.Value] or Enum.EasingStyle.Linear, Enum.EasingDirection[component.EasingDirection.Value], component.RepeatCount.Value, component.Reverses.Value, component.DelayTime.Value),
			{CFrame = cf}
		)
		tween:Play()
		if timeToWait ~= "n/a" then
			wait(timeToWait)
		end
	end
	
	local function TweenPartRotation(component)
		local timeToWait = component.RepeatCount.Value >= 0 and (component.Time.Value + (component.Reverses.Value and component.Time.Value or 0) + (component.RepeatCount.Value * component.Time.Value) + component.DelayTime.Value) or "n/a"
		local cf = component.LocalCoords.Value and (component.Parent.CFrame * CFrame.Angles(math.rad(component.X.Value), math.rad(component.Y.Value), math.rad(component.Z.Value))) or CFrame.new(component.Parent.CFrame.p) * CFrame.Angles(math.rad(component.X.Value), math.rad(component.Y.Value), math.rad(component.Z.Value))
		local tween = game:GetService("TweenService"):Create(
			component.Parent,
			TweenInfo.new(component.Time.Value, Enum.EasingStyle[component.EasingStyle.Value] or Enum.EasingStyle.Linear, Enum.EasingDirection[component.EasingDirection.Value], component.RepeatCount.Value, component.Reverses.Value, component.DelayTime.Value),
			{CFrame = cf}
		)
		tween:Play()
		if timeToWait ~= "n/a" then
			wait(timeToWait)
		end
	end
	
	local function setupTweenPosition(component)
		if component.Trigger.Value then
			if component.Trigger.Value:FindFirstChild("Event") then
				-- client prediction event
				component.Trigger.Value.Event.Event:connect(function()
						if component.Enabled.Value == true then
						component.Enabled.Value = false
						TweenPartPosition(component)
						component.Enabled.Value = true
					end
				end)
			end
			if component.Trigger.Value:FindFirstChild("RemoteEvent") then
				-- server event
				component.Trigger.Value.RemoteEvent.OnClientEvent(function()
					TweenPartPosition(component)
				end)
			end
		end
	end
	
	local function setupTweenRotation(component)
		if component.Trigger.Value then
			if component.Trigger.Value:FindFirstChild("Event") then
				-- client prediction event
				component.Trigger.Value.Event.Event:connect(function()
						if component.Enabled.Value == true then
						component.Enabled.Value = false
						TweenPartRotation(component)
						component.Enabled.Value = true
					end
				end)
			end
			if component.Trigger.Value:FindFirstChild("RemoteEvent") then
				-- server event
				component.Trigger.Value.RemoteEvent.OnClientEvent(function()
					TweenPartRotation(component)
				end)
			end
		end
	end
	
	if componentEntityMap.TweenPartPosition then
		for _, component in ipairs(componentEntityMap.TweenPartPosition) do
			setupTweenPosition(component)
		end
	end
	
	if componentEntityMap.TweenPartRotation then
		for _, component in ipairs(componentEntityMap.TweenPartRotation) do
			setupTweenRotation(component)
		end	
	end
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		Utilities.YieldUntilComponentLoaded(component)
		if component.Name == "TweenPartPosition" then
			setupTweenPosition(component)
		elseif component.Name == "TweenPartRotation" then
			setupTweenRotation(component)
		end
	end)
	
end

return TweenSystem
