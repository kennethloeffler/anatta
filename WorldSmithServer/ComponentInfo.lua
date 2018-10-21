local WorldSmithUtilities = require(script.Parent.WorldSmithServerUtilities)

ComponentInfo = {
	["ContextActionTrigger"] = {
		Enabled = "boolean",
		desktopPC = "string",
		mobile = "string",
		console = "string",
		MaxDistance = "number",
		CreateTouchButton = "boolean"
	},
	["CharacterConstraint"] = {
		CharacterPoseId = "number",
		Enabled = "boolean",
		Label = "string"
	},
	["TouchTrigger"] = {
		Enabled = "boolean"
	},
	["TweenPartPosition"] = {
		Enabled = "boolean",
		LocalCoords = "boolean",
		ClientSide = "boolean",
		Trigger = "Instance",
		Time = "number",
		EasingStyle = "string",
		EasingDirection = "string",
		Reverses = "boolean",
		RepeatCount = "number",
		DelayTime = "number",
		X = "number",
		Y = "number",
		Z = "number"
	},
	["TweenPartRotation"] = {
		Enabled = "boolean",
		ClientSide = "boolean",
		LocalCoords = "boolean",
		Trigger = "Instance",
		Time = "number",
		EasingStyle = "string",
		EasingDirection = "string",
		Reverses = "boolean",
		RepeatCount = "number",
		DelayTime = "number",
		X = "number",
		Y = "number",
		Z = "number"
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
			end
		end
	},
	["Vehicle"] = {
		Enabled = "boolean",
		MainPart = "Instance",
		EnterTrigger = "Instance",
		AccelerationRate = "number",
		BrakeDeceleration = "number",
		MaxTurnSpeed = "number",
		TurnRate = "number",
		MaxSpeed = "number",
		MaxForce = "number",
		DriverConstraint = "Instance",
		AdditionalCharacterConstraints = "Instance",
		["_init"] = function(parameters, container)
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
		end
	},
}



return ComponentInfo
