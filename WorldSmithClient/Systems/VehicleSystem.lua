local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Utilities = require(script.Parent.Parent.WorldSmithClientUtilities)

local VehicleSystem = {}
VehicleSystem.InVehicle = false

function VehicleSystem.Start(componentEntityMap)
	
	local function setupVehicle(component)
		component.RemoteEvent.OnClientEvent:connect(function(parameters, argType)
			if argType == "enterVehicle" then
				local currentRot = 0
				local currentVelocity = 0
				local bodyVelocity = Instance.new("BodyVelocity", component.MainPart.Value)
				local bodyGyro = Instance.new("BodyGyro", component.MainPart.Value)
				
				VehicleSystem.inVehicle = true
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
							VehicleSystem.inVehicle = false
							component.RemoteEvent:FireServer("exitVehicle")
						end
					end, 
					true, 
					Utilities.UnpackInputs(component.EnterTrigger.Value)
				)
				ContextActionService:BindAction(
					"Throttle",
					function(actionName, inputState, inputObj)
						while wait() do
							local addedVelocity = currentVelocity + parameters.AccelerationRate <= parameters.MaxSpeed and parameters.AccelerationRate or 0
							if inputObj.UserInputState ~= Enum.UserInputState.Begin or not VehicleSystem.inVehicle then 
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
							if inputObj.UserInputState ~= Enum.UserInputState.Begin or not VehicleSystem.inVehicle then 
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
							if inputObj.UserInputState ~= Enum.UserInputState.Begin or not VehicleSystem.inVehicle then
								currentRot = 0
								break 
							end
							if math.abs(currentVelocity) > 0.1 then
								bodyGyro.CFrame = CFrame.fromMatrix(component.MainPart.Value.CFrame.p, -component.MainPart.Value.CFrame.RightVector, Vector3.new(0, 1, 0), -component.MainPart.Value.CFrame.LookVector) * CFrame.Angles(0, math.rad(-(currentRot + addedRot) / 2), 0)
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
							if inputObj.UserInputState ~= Enum.UserInputState.Begin or not VehicleSystem.inVehicle then
								currentRot = 0
								break 
							end
							if math.abs(currentVelocity) > 0.1 then
								bodyGyro.CFrame = CFrame.fromMatrix(component.MainPart.Value.CFrame.p, -component.MainPart.Value.CFrame.RightVector, Vector3.new(0, 1, 0), -component.MainPart.Value.CFrame.LookVector) * CFrame.Angles(0, math.rad(currentRot + addedRot), 0)
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
				spawn(function() 
					while (VehicleSystem.inVehicle or math.abs(currentVelocity) > 0) do
						if math.abs(currentVelocity) > parameters.BrakeDeceleration * 2 then
							currentVelocity = currentVelocity > 0 and currentVelocity - parameters.BrakeDeceleration or currentVelocity + parameters.BrakeDeceleration
						else
							currentVelocity = 0
						end
						bodyVelocity.Velocity = component.MainPart.Value.CFrame.LookVector.unit * (currentVelocity)
						wait()
					end
				end)
			end
		end)
	end
	
	if componentEntityMap.Vehicle then
		for _, component in ipairs(componentEntityMap.Vehicle) do
			setupVehicle(component)
		end
	end
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		if component.Name == "Vehicle" then
			Utilities.YieldUntilComponentLoaded(component)
			setupVehicle(component)
		end
	end)
end

return VehicleSystem
