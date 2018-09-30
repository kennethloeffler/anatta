local WorldObject = require(script.Parent.WorldObject)

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
	trigger.Size = size
	trigger.Transparency = 1
	trigger.CFrame = cframe
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Parent = container
	
	local _, cont = WorldObject.new(trigger, "TouchTrigger", {Enabled = true})
	
	if cont:IsA("Folder") then 
		container[triggerName].Value = cont
		WorldObjectInfo.TouchTrigger._init({Enabled = true}, cont)
	end
	
end

WorldObjectInfo = {
	["AnimatedDoor"] = {
		Enabled = "boolean",
		AutomaticTriggers = "boolean",
		Time = "number",
		OpenDirection = "number",
		CloseDelay = "number",
		EasingStyle = "string",
		TriggerOffset = "number",
		PivotPart = "Instance",
		FrontTrigger = "Instance",
		BackTrigger = "Instance",
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
			local frontDirection = parameters.OpenDirection == 0 and 1 or parameters.OpenDirection
			local backDirection = parameters.OpenDirection == 0 and -1 or parameters.OpenDirection
			local frontEventObj = (parameters.FrontTrigger:FindFirstChild("Event") and "Event") or (parameters.FrontTrigger:FindFirstChild("RemoteEvent") and "RemoteEvent")
			local backEventObj = (parameters.BackTrigger:FindFirstChild("Event") and "Event") or (parameters.BackTrigger:FindFirstChild("RemoteEvent") and "RemoteEvent")
			local frontEvent = (parameters.FrontTrigger:FindFirstChild("Event") and "Event")  or (parameters.FrontTrigger:FindFirstChild("RemoteEvent") and "OnServerEvent")
			local backEvent = (parameters.BackTrigger:FindFirstChild("Event") and "Event") or (parameters.BackTrigger:FindFirstChild("RemoteEvent") and "OnServerEvent")
			parameters.FrontTrigger[frontEventObj][frontEvent]:connect(function(part)
				local player = game.Players:GetPlayerFromCharacter(part.Parent)
				if part.Parent:FindFirstChild("Humanoid") then
					AnimateDoor(parameters, frontDirection, container.RemoteEvent, player, container)
				end
			end)
			parameters.BackTrigger[backEventObj][backEvent]:connect(function(part)
				local player = game.Players:GetPlayerFromCharacter(part.Parent)
				if part.Parent:FindFirstChild("Humanoid") then
					AnimateDoor(parameters, backDirection, container.RemoteEvent, player, container)
				end
			end)
		end
	},
	["TouchTrigger"] = {
		Enabled = "boolean",
		["_init"] = function(parameters, container)
			if container.Parent:IsA("BasePart") then
				local bindableEvent = Instance.new("BindableEvent")
				bindableEvent.Parent = container
			end
		end,
		["_connectEventsFunction"] = function(parameters, container)
			if container.Parent:IsA("BasePart") then
				container.Parent.Touched:connect(function(part)
					if container.Enabled.Value == true then
						container.Event:Fire(part)
					end
				end)
			end
		end
	},
	["ContextActionTrigger"] = {
		Enabled = "boolean",
		InputType = "string",
		InputEnum = "string",
		MaxDistance = "number",
		CreateTouchButton = "boolean",
		["_init"] = function(parameters, container)
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Parent = container
		end,
		["_connectEventsFunction"] = function(parameters, container)
			container.RemoteEvent.OnServerEvent:connect(function(player)
				print(player.Name)
			end)
		end
	}
}



return WorldObjectInfo
