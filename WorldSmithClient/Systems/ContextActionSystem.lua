local ContextActionService = game:GetService("ContextActionService")
local Utilities = require(script.Parent.Parent.WorldSmithClientUtilities)

local ContextActionSystem = {}

local TotalContextActions = 0
local ContextActions = {}
	
function ContextActionSystem.Start(componentEntityMap)
	while game:GetService("RunService").Heartbeat:wait() do

		local contextActionsNear = {}
		
		if componentEntityMap.ContextActionTrigger then
			for _, component in ipairs(componentEntityMap.ContextActionTrigger) do
				if component.Parent:IsA("BasePart") then
					if not ContextActions[component] then TotalContextActions = TotalContextActions + 1 ContextActions[component] = TotalContextActions end
					if (component.Parent.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= component.MaxDistance.Value and component.Enabled.Value == true then
						contextActionsNear[#contextActionsNear + 1] = component
					else
						ContextActionService:UnbindAction(tostring(ContextActions[component]))
					end
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
