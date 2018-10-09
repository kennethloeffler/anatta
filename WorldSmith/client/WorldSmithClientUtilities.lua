local ContextActionService = game:GetService("ContextActionService")

local WorldSmithUtilities = {}

local clientSideActiveWorldObjects = {}
local clientSideAssignedWorldObjects = {}

WorldSmithUtilities.inVehicle = false

function WorldSmithUtilities.YieldUntilComponentLoaded(component)
	local firstTime = tick()
	local lastNum = 0
	while true do
		local numChildren = #component:GetChildren()
		if numChildren > 0 then
			lastNum = numChildren
		end
		game:GetService("RunService").Heartbeat:wait()
		if lastNum > 0 and lastNum == numChildren then break end
	end
end

function WorldSmithUtilities.CreateArgDictionary(componentChildren)
	local t = {}
	for i, v in ipairs(componentChildren) do
		if v:IsA("ValueBase") then
			t[v.Name] = v.Value
		end
	end
	return t
end

function WorldSmithUtilities.UnpackInputs(componentRef)
	local desktopPCEnum1, desktopPCEnum2 = componentRef.desktopPC.Value:match("([^,]+),([^,]+)")
	local mobileEnum1, mobileEnum2 = componentRef.mobile.Value:match("([^,]+),([^,]+)")
	local consoleEnum1, consoleEnum2 = componentRef.console.Value:match("([^,]+),([^,]+)")
	local inputs = {componentRef.desktopPC.Value ~= "" and Enum[desktopPCEnum1][desktopPCEnum2] or nil, componentRef.mobile.Value ~= "" and Enum[mobileEnum1][mobileEnum2] or nil, componentRef.console.Value ~= "" and Enum[consoleEnum1][consoleEnum2] or nil}
	return unpack(inputs)
end

function WorldSmithUtilities.Query(componentRef, param)
	if componentRef[param] then
		return componentRef[param].Value
	else
		error("WorldObject '".. componentRef.Name .. "' does not have parameter '" .. param .. "'")
	end
end

function WorldSmithUtilities.TweenPartPosition(parameters, argType, componentRef, player)
	if player ~= game.Players.LocalPlayer and clientSideActiveWorldObjects[componentRef] == nil then
		clientSideActiveWorldObjects[componentRef] = true
		local timeToWait = parameters.RepeatCount >= 0 and (parameters.Time + (parameters.Reverses and parameters.Time or 0) + (parameters.RepeatCount * parameters.Time) + parameters.DelayTime) or "n/a"
		local cf = parameters.LocalCoords and (componentRef.Parent.CFrame * CFrame.new(parameters.X, parameters.Y, parameters.Z)) or CFrame.new(parameters.X, parameters.Y, parameters.Z)
		local tween = game:GetService("TweenService"):Create(
			componentRef.Parent,
			TweenInfo.new(parameters.Time, Enum.EasingStyle[parameters.EasingStyle] or Enum.EasingStyle.Linear, Enum.EasingDirection[parameters.EasingDirection], parameters.RepeatCount, parameters.Reverses, parameters.DelayTime),
			{CFrame = cf}
		)
		tween:Play()
		if timeToWait ~= "n/a" then
			wait(timeToWait)
			clientSideActiveWorldObjects[componentRef] = nil
		end
	end
end

function WorldSmithUtilities.TweenPartRotation(parameters, argType, componentRef, player)
	if player ~= game.Players.LocalPlayer and clientSideActiveWorldObjects[componentRef] == nil then
		clientSideActiveWorldObjects[componentRef] = true
		local timeToWait = parameters.RepeatCount >= 0 and (parameters.Time + (parameters.Reverses and parameters.Time or 0) + (parameters.RepeatCount * parameters.Time) + parameters.DelayTime) or "n/a"
		local cf = parameters.LocalCoords and (componentRef.Parent.CFrame * CFrame.Angles(math.rad(parameters.X), math.rad(parameters.Y), math.rad(parameters.Z))) or CFrame.new(componentRef.Parent.CFrame.p) * CFrame.Angles(math.rad(parameters.X), math.rad(parameters.Y), math.rad(parameters.Z))
		local tween = game:GetService("TweenService"):Create(
			componentRef.Parent,
			TweenInfo.new(parameters.Time, Enum.EasingStyle[parameters.EasingStyle] or Enum.EasingStyle.Linear, Enum.EasingDirection[parameters.EasingDirection], parameters.RepeatCount, parameters.Reverses, parameters.DelayTime),
			{CFrame = cf}
		)
		tween:Play()
		if timeToWait ~= "n/a" then
			wait(timeToWait)
			clientSideActiveWorldObjects[componentRef] = nil
		end
	end
end

function WorldSmithUtilities.AnimatedDoor(parameters, dir, componentRef, player)
	if not clientSideActiveWorldObjects[componentRef] and player ~= game.Players.LocalPlayer then
		clientSideActiveWorldObjects[componentRef] = true
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
		clientSideActiveWorldObjects[componentRef] = nil
	end
end

function WorldSmithUtilities.Vehicle(parameters, argType, componentRef)
	local currentRot = 0
	local currentVelocity = 0
	local bodyVelocity = Instance.new("BodyVelocity", componentRef.MainPart.Value)
	local bodyGyro = Instance.new("BodyGyro", componentRef.MainPart.Value)
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
					ContextActionService:UnbindAction("ExitVehicle")
					ContextActionService:UnbindAction("Throttle")
					ContextActionService:UnbindAction("Reverse")
					ContextActionService:UnbindAction("Left")
					ContextActionService:UnbindAction("Right")
					bodyVelocity:Destroy()
					bodyGyro:Destroy()
					WorldSmithUtilities.inVehicle = false
					componentRef.RemoteEvent:FireServer("exitVehicle")
				end
			end, 
			true, 
			WorldSmithUtilities.UnpackInputs(componentRef.EnterTrigger.Value)
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
						bodyGyro.CFrame = CFrame.fromMatrix(componentRef.MainPart.Value.CFrame.p, -componentRef.MainPart.Value.CFrame.RightVector, Vector3.new(0, 1, 0), -componentRef.MainPart.Value.CFrame.LookVector) * CFrame.Angles(0, math.rad(-(currentRot + addedRot)), 0)
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
						bodyGyro.CFrame = CFrame.fromMatrix(componentRef.MainPart.Value.CFrame.p, -componentRef.MainPart.Value.CFrame.RightVector, Vector3.new(0, 1, 0), -componentRef.MainPart.Value.CFrame.LookVector) * CFrame.Angles(0, math.rad(currentRot + addedRot), 0)
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
			bodyVelocity.Velocity = componentRef.MainPart.Value.CFrame.LookVector.unit * (currentVelocity)
			wait()
		end
	end)
end

return WorldSmithUtilities
