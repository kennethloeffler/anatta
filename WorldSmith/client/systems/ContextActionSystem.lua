local ContextActionService = game:GetService("ContextActionService")
local Utilities = require(script.Parent.Parent.WorldSmithClientUtilities)

local ContextActionSystem = {}

local TotalContextActions = 0
local ContextActions = {}
	
function ContextActionSystem.Start(componentEntityMap)
	while wait(0.1) do
		
		local contextActionsNear = {}
		
		for entity, _ in pairs(componentEntityMap.ContextActionTrigger) do
			if entity:IsA("BasePart") then
				local componentRef = entity.ContextActionTrigger
				if not ContextActions[componentRef] then TotalContextActions = TotalContextActions + 1 ContextActions[componentRef] = TotalContextActions end
				if (entity.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= componentRef.MaxDistance.Value and componentRef.Enabled.Value == true and not Utilities.inVehicle then
					contextActionsNear[#contextActionsNear + 1] = componentRef
				else
					ContextActionService:UnbindAction(tostring(ContextActions[componentRef]))
				end
			end
		end
		
		local lastActionPos = math.huge
		local setAction

		for _, componentRef in ipairs(contextActionsNear) do
			local newActionPos = (componentRef.Parent.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude
			if newActionPos < lastActionPos then
				lastActionPos = newActionPos
				setAction = componentRef
			end
		end
		
		if setAction then
			local function contextActionFunction(actionName, inputState, inputObj)
				if inputState == Enum.UserInputState.Begin then
					setAction.Event:Fire()
					setAction.RemoteEvent:FireServer()
				end
			end
			ContextActionService:BindAction(tostring(ContextActions[setAction]), contextActionFunction, setAction.CreateTouchButton.Value, Utilities.UnpackInputs(setAction))
		end	
	end
end

return ContextActionSystem
