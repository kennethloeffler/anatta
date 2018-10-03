local ContextActionService = game:GetService("ContextActionService")

local WorldSmithUtilities = {}

local clientSideActiveWorldObjects = {}
local clientSideAssignedWorldObjects = {}

WorldSmithUtilities.inVehicle = false

function WorldSmithUtilities.YieldUntilComponentLoaded(component)
	while true do
		local numChildren = #component:GetChildren()
		if numChildren > 0 then
			break
		end
		game:GetService("RunService").Heartbeat:wait()
	end
end

function WorldSmithUtilities.CreateArgDictionary(paramContainerChildren)
	local t = {}
	local c = paramContainerChildren
	for i, v in ipairs(c) do
		if v:IsA("ValueBase") then
			t[v.Name] = v.Value
		end
	end
	return t
end

function WorldSmithUtilities.QueryWorldObject(worldObjectRef, param)
	if worldObjectRef[param] then
		return worldObjectRef[param].Value
	else
		error("WorldObject '".. worldObjectRef.Name .. "' does not have parameter '" .. param .. "'")
	end
end

function WorldSmithUtilities.AnimatedDoor(parameters, dir, worldObjectRef, player)
	if not clientSideActiveWorldObjects[worldObjectRef] and player ~= game.Players.LocalPlayer then
		clientSideActiveWorldObjects[worldObjectRef] = true
		local cf1 = parameters.PivotPart.CFrame * CFrame.Angles(0, dir * (math.pi / 2), 0)
		local tween1 = game:GetService("TweenService"):Create(
			parameters.PivotPart,
			TweenInfo.new(parameters.Time / 2, Enum.EasingStyle[parameters.EasingStyle] or Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0),
			{CFrame = cf1}
		)
		tween1:Play()
		wait(parameters.Time / 2)
		local cf2 = parameters.PivotPart.CFrame * CFrame.Angles(0, dir * (-math.pi / 2), 0)
		local tween2 = game:GetService("TweenService"):Create(
			parameters.PivotPart,
			TweenInfo.new(parameters.Time/2, Enum.EasingStyle[parameters.EasingStyle] or Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, parameters.CloseDelay or 0),
			{CFrame = cf2}
		)
		tween2:Play()
		wait((parameters.Time / 2) + parameters.CloseDelay)
		clientSideActiveWorldObjects[worldObjectRef] = nil
	end
end

function WorldSmithUtilities.Vehicle(parameters, argType, worldObjectRef)
	local currentRot = 0
	local currentVelocity = 0
	local bodyVelocity = worldObjectRef.MainPart.Value.BodyVelocity --Instance.new("BodyVelocity", worldObjectRef.MainPart.Value)
	local bodyGyro = worldObjectRef.MainPart.Value.BodyGyro--Instance.new("BodyGyro", worldObjectRef.MainPart.Value)
	if argType == "enterVehicle" then
		WorldSmithUtilities.inVehicle = true
		game.Players.LocalPlayer.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
		game.Players.LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		ContextActionService:BindAction(
			"ExitVehicle",
			function(actionName, inputState, inputObj)
				if inputState == Enum.UserInputState.Begin then
					game.Players.LocalPlayer.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
					game.Players.LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
					game.Players.LocalPlayer.Character.HumanoidRootPart:FindFirstChild("Weld"):Destroy()
					ContextActionService:UnbindAction("ExitVehicle")
					ContextActionService:UnbindAction("Throttle")
					ContextActionService:UnbindAction("Reverse")
					ContextActionService:UnbindAction("Left")
					ContextActionService:UnbindAction("Right")
					WorldSmithUtilities.inVehicle = false
					worldObjectRef.RemoteEvent:FireServer("exitVehicle")
				end
			end, 
			true, 
			Enum[worldObjectRef.EnterTrigger.Value.InputEnum.Value][worldObjectRef.EnterTrigger.Value.InputType.Value]
		)
		ContextActionService:BindAction(
			"Throttle",
			function(actionName, inputState, inputObj)
				while wait() do
					local addedVelocity = currentVelocity + parameters.AccelerationRate <= parameters.MaxSpeed and parameters.AccelerationRate or 0
					if inputObj.UserInputState ~= Enum.UserInputState.Begin or not WorldSmithUtilities.inVehicle then 
						break 
					end
					bodyVelocity.MaxForce = Vector3.new(1, 0, 1) * parameters.MaxForce
					currentVelocity = currentVelocity + addedVelocity
				end
			end,
			false,
			Enum.KeyCode.W
		)
		ContextActionService:BindAction(
			"Reverse",
			function(actionName, inputState, inputObj)
				while wait() do
					local addedVelocity = math.abs(currentVelocity - parameters.AccelerationRate) <= parameters.MaxSpeed and parameters.AccelerationRate or 0
					if inputObj.UserInputState ~= Enum.UserInputState.Begin or not WorldSmithUtilities.inVehicle then 
						break 
					end
					bodyVelocity.MaxForce = Vector3.new(1, 0, 1) * parameters.MaxForce
					currentVelocity = currentVelocity - addedVelocity
				end
			end,
			false,
			Enum.KeyCode.S
		)
		ContextActionService:BindAction(
			"Left",
			function(actionName, inputState, inputObj)
				while wait() do
					local addedRot = math.abs(currentRot - parameters.TurnRate) <= parameters.MaxTurnSpeed and parameters.TurnRate or 0
					if inputObj.UserInputState ~= Enum.UserInputState.Begin or not WorldSmithUtilities.inVehicle then
						currentRot = 0
						break 
					end
					if math.abs(currentVelocity) > 0.1 then
						bodyGyro.CFrame = CFrame.fromMatrix(worldObjectRef.MainPart.Value.CFrame.p, -worldObjectRef.MainPart.Value.CFrame.RightVector, Vector3.new(0, 1, 0), -worldObjectRef.MainPart.Value.CFrame.LookVector) * CFrame.Angles(0, math.rad(-(currentRot + addedRot)), 0)
						currentRot = currentRot + addedRot
						bodyGyro.MaxTorque = Vector3.new(1, 1, 1) * parameters.MaxForce
					else
						bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
						currentRot = 0
					end
				end
			end,
			false,
			Enum.KeyCode.A
		)
		ContextActionService:BindAction(
			"Right",
			function(actionName, inputState, inputObj)
				while wait() do
					local addedRot = math.abs(currentRot + parameters.TurnRate) <= parameters.MaxTurnSpeed and parameters.TurnRate or 0
					if inputObj.UserInputState ~= Enum.UserInputState.Begin or not WorldSmithUtilities.inVehicle then
						currentRot = 0
						break 
					end
					if math.abs(currentVelocity) > 0.1 then
						bodyGyro.CFrame = CFrame.fromMatrix(worldObjectRef.MainPart.Value.CFrame.p, -worldObjectRef.MainPart.Value.CFrame.RightVector, Vector3.new(0, 1, 0), -worldObjectRef.MainPart.Value.CFrame.LookVector) * CFrame.Angles(0, math.rad(currentRot + addedRot), 0)
						currentRot = currentRot + addedRot
						bodyGyro.MaxTorque = Vector3.new(1, 1, 1) * parameters.MaxForce
					else
						bodyGyro.MaxTorque = Vector3.new(0, 0, 0)
						currentRot = 0
					end
				end
			end,
			false,
			Enum.KeyCode.D
		)
	end
	spawn(function() 
		while (WorldSmithUtilities.inVehicle or math.abs(currentVelocity) > 0) do
			if math.abs(currentVelocity) > parameters.BrakeDeceleration * 2 then
				currentVelocity = currentVelocity > 0 and currentVelocity - parameters.BrakeDeceleration or currentVelocity + parameters.BrakeDeceleration
			else
				currentVelocity = 0
			end
			bodyVelocity.Velocity = worldObjectRef.MainPart.Value.CFrame.LookVector.unit * (currentVelocity)
			wait()
		end
	end)
end

return WorldSmithUtilities
