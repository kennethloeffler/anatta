local CollectionService = game:GetService("CollectionService")
local Utilities = require(script.Parent.Parent.WorldSmithServerUtilities)

local VehicleSystem = {}

function VehicleSystem.Start(componentEntityMap)
	
	local function setupVehicle(component)
		if component.EnterTrigger.Value:IsA("Folder") then
			if component:FindFirstChild("RemoteEvent") then component.RemoteEvent:Destroy() end -- otherwise will bug client/leave behind a purposeless remote when cloned during runtime
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Parent = component
			component.EnterTrigger.Value.RemoteEvent.OnServerEvent:connect(function(arg)
				local maxCapacity = (component:FindFirstChild("AdditionalCharacterContraints") and #component.AdditionalCharacterConstraints.Value:GetChildren() or 0) + 1
				if component.EnterTrigger.Value.Enabled.Value == true and component._totalOccupants.Value <= maxCapacity then
					local player = game.Players:GetPlayerFromCharacter(arg.Parent) or arg
					component.MainPart.Value:SetNetworkOwner(player)
					remoteEvent:FireClient(player, Utilities.CreateArgDictionary(component:GetChildren()), "enterVehicle")
					Utilities.ConstrainCharacter(player, component.DriverConstraint.Value)
					component._totalOccupants.Value = component._totalOccupants.Value + 1
					if component._totalOccupants.Value == maxCapacity then
						component.EnterTrigger.Value.Enabled.Value = false
					end
				end
			end)
			remoteEvent.OnServerEvent:connect(function(player, argType, arg)
				if argType == "exitVehicle" then
					player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
					player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
					component.EnterTrigger.Value.Enabled.Value = true
					player.Character.HumanoidRootPart:FindFirstChild("CharacterConstraint"):Destroy()
					component._totalOccupants.Value = component._totalOccupants.Value - 1
					repeat wait() until component.MainPart.Value.Velocity.magnitude < 0.1
					component.MainPart.Value:SetNetworkOwner(nil)	
				end
			end)
		end
	end
	
	if componentEntityMap.Vehicle then
		for _, component in ipairs(componentEntityMap.Vehicle) do
			setupVehicle(component)
		end
	end
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		if component.Name == "Vehicle" then
			setupVehicle(component)
		end
	end)
	
end

return VehicleSystem
