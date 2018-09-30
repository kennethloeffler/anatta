local WorldSmithUtilities = require(script.Parent.WorldSmithServerUtilities)

WorldObjectInfo = {
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
					local frontTrigger = WorldSmithUtilities.CreateTouchTrigger(parameters.PivotPart.CFrame * CFrame.new(modelSize.X/2 - pivotSize.X/2, 0, 1 + parameters.TriggerOffset), Vector3.new(modelSize.X, modelSize.Y, 1), container, "FrontTrigger")
					local backTrigger = WorldSmithUtilities.CreateTouchTrigger(parameters.PivotPart.CFrame * CFrame.new(modelSize.X/2 - pivotSize.X/2, 0, -1 - parameters.TriggerOffset), Vector3.new(modelSize.X, modelSize.Y, 1), container, "BackTrigger")

				end
				parameters.PivotPart.Anchored = true
				local remoteEvent = Instance.new("RemoteEvent")
				remoteEvent.Parent = container
			end
		end,
		["_connectEventsFunction"] = function(parameters, container)
			local frontDirection = parameters.OpenDirection == 0 and 1 or parameters.OpenDirection
			local backDirection = parameters.OpenDirection == 0 and -1 or parameters.OpenDirection
			local frontEventObj, frontEventName = WorldSmithUtilities.GetTriggerEventNames(parameters.FrontTrigger)
			parameters.FrontTrigger[frontEventObj][frontEventName]:connect(function(part)
				local player = game.Players:GetPlayerFromCharacter(part.Parent)
				if part.Parent:FindFirstChild("Humanoid") or part:IsA("Player") then
					WorldSmithUtilities.AnimateDoor(parameters, frontDirection, container.RemoteEvent, player, container)
				end
			end)
			local backEventObj, backEventName = WorldSmithUtilities.GetTriggerEventNames(parameters.BackTrigger)
			parameters.BackTrigger[backEventObj][backEventName]:connect(function(part)
				local player = game.Players:GetPlayerFromCharacter(part.Parent) or part
				if part.Parent:FindFirstChild("Humanoid") or part:IsA("Player") then
					WorldSmithUtilities.AnimateDoor(parameters, backDirection, container.RemoteEvent, player, container)
				end
			end)
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
			local bindableEvent = Instance.new("BindableEvent")
			bindableEvent.Parent = container
		end
	},
	["CharacterConstraint"] = {
		CharacterPoseId = "number",
		Enabled = "boolean",
		Label = "string"
	},
	["Vehicle"] = {
		Enabled = "boolean",
		CameraFollowsVehicle = "boolean",
		MainPart = "Instance",
		AutoTrigger = "boolean",
		EnterTrigger = "Instance",
		AccelerationRate = "number",
		TurnRate = "number",
		MaxSpeed = "number",
		MaxAcceleration = "number",
		WheelContainer = "Instance",
		DriverConstraint = "Instance",
		AdditionalCharacterConstraints = "Instance",
		["_init"] = function(parameters, container)
			local remoteEvent = Instance.new("RemoteEvent", container)
			local bodyForce = Instance.new("BodyForce", parameters.MainPart)
			local bodyGyro = Instance.new("BodyGyro", parameters.MainPart)
			bodyForce.Name = "BodyForce"
			bodyGyro.Name = "BodyGyro"
			for _, part in pairs(container.Parent:GetChildren()) do
				if part:IsA("BasePart") then
					local motor6d = Instance.new("Motor6D")
					motor6d.Parent = part
					motor6d.C0 = part.CFrame:inverse() * parameters.MainPart.CFrame
					motor6d.Part0 = part
					motor6d.Part1 = parameters.MainPart
					part.Anchored = false
				elseif part:IsA("Model") and part ~= parameters.WheelContainer then
					for _, subPart in pairs(part:GetChildren()) do
						local motor6d = Instance.new("Motor6D")
						motor6d.Parent = subPart
						motor6d.C0 = subPart.CFrame:inverse() * parameters.MainPart.CFrame
						motor6d.Part0 = subPart
						motor6d.Part1 = parameters.MainPart
						subPart.Anchored = false
					end
				end
			end
			parameters.MainPart.Anchored = false
		end,
		["_connectEventsFunction"] = function(parameters, container)
			if parameters.EnterTrigger then
				local totalOccupants = 0
				local eventObj, eventName = WorldSmithUtilities.GetTriggerEventNames(parameters.EnterTrigger)
				parameters.EnterTrigger.RemoteEvent.OnServerEvent:connect(function(arg)
					local maxCapacity = (parameters.AdditionalCharacterContraints and #container.AdditionalCharacterConstraints.Value:GetChildren() or 0) + 1
					if totalOccupants < maxCapacity then
						local player = game.Players:GetPlayerFromCharacter(arg.Parent) or arg
						WorldSmithUtilities.ConstrainCharacter(player, parameters.DriverConstraint)
						totalOccupants = totalOccupants + 1
						container.RemoteEvent:FireClient(arg, "enterVehicle", totalOccupants)
						container.MainPart.Value:SetNetworkOwner(player)
					end
				end)
			end
			if not parameters.EnterTrigger and parameters.AutoTrigger == true then
				-- TODO: setup auto context action trigger
			end
			container.RemoteEvent.OnServerEvent:connect(function(player, argType, arg)
				
			end)
		end
	}
}



return WorldObjectInfo
