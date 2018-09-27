local function AnimateDoor(parameters, dir, remoteEvent, player, container)
	if container.Enabled.Value == true then
		container.Enabled.Value = false
		remoteEvent:FireAllClients(player, parameters, dir)
		wait(parameters.Time + parameters.CloseDelay)
		container.Enabled.Value = true
	end
end

local function SetDisabled(parameters)
	parameters.Enabled = not parameters.Enabled
end

local function createTrigger(cframe, size, container, triggerName)
	local trigger = Instance.new("Part")
	local value = Instance.new("ObjectValue")
	trigger.Size = size
	trigger.Transparency = 1
	trigger.CFrame = cframe
	trigger.Anchored = true
	trigger.CanCollide = false
	value.Name = triggerName
	value.Value = trigger
	trigger.Parent = container
	value.Parent = container
end

local WorldObjectInfo = {
	["AnimatedDoor"] = {
		Enabled = "boolean",
		AutomaticTriggers = "boolean",
		Time = "number",
		CloseDelay = "number",
		EasingStyle = "string",
		TriggerOffset = "number",
		PivotPart = "Instance",
		["_init"] = function(parameters, container)
			if parameters.PivotPart.Parent:IsA("Model") then
				for _, part in pairs(parameters.PivotPart.Parent:GetChildren()) do
					if part ~= parameters.PivotPart and part:IsA("BasePart") then
						local motor6d = Instance.new("Motor6D")
						motor6d.Parent = part
						motor6d.C0 = part.CFrame:inverse() * parameters.PivotPart.CFrame
						motor6d.Part0 = part
						motor6d.Part1 = parameters.PivotPart
						part.Anchored = false
					end
				end
				if parameters.AutomaticTriggers == true then
					local modelSize = parameters.PivotPart.Parent:GetModelSize()
					local pivotSize = parameters.PivotPart.Size
					local frontTrigger = createTrigger(parameters.PivotPart.CFrame * CFrame.new(modelSize.X/2 - pivotSize.X/2, 0, 1 + parameters.TriggerOffset), Vector3.new(modelSize.X, modelSize.Y, 1), container, "FrontTrigger")
					local backTrigger = createTrigger(parameters.PivotPart.CFrame * CFrame.new(modelSize.X/2 - pivotSize.X/2, 0, -1 - parameters.TriggerOffset), Vector3.new(modelSize.X, modelSize.Y, 1), container, "BackTrigger")

				end
				parameters.PivotPart.Anchored = true
				local remoteEvent = Instance.new("RemoteEvent")
				remoteEvent.Parent = container
			end
		end,
		["_connectEventsFunction"] = function(parameters, container)
			parameters.FrontTrigger.Touched:connect(function(part)
				local player = game.Players:GetPlayerFromCharacter(part.Parent)
				if part.Parent:FindFirstChild("Humanoid") then
					AnimateDoor(parameters, 1, container.RemoteEvent, player, container)
				end
			end)
			parameters.BackTrigger.Touched:connect(function(part)
				local player = game.Players:GetPlayerFromCharacter(part.Parent)
				if part.Parent:FindFirstChild("Humanoid") then
					AnimateDoor(parameters, -1, container.RemoteEvent, player, container)
				end
			end)
		end
	},
	["PhysicsDoor"] = {
		
	}
}



return WorldObjectInfo
