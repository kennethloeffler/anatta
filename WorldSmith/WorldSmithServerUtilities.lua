local WorldObject = require(script.Parent.WorldObject)

local WorldSmithUtilities = {}


function WorldSmithUtilities.YieldUntilComponentLoaded(component)
	while true do
		local numChildren = #component:GetChildren()
		if numChildren > 0 then
			break
		end
		game:GetService("RunService").Heartbeat:wait()
	end
end
function WorldSmithUtilities.CreateTouchTrigger(cframe, size, container, triggerName, initFunction)
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
		if cont.Parent:IsA("BasePart") then
			local bindableEvent = Instance.new("BindableEvent")
			bindableEvent.Parent = cont
		end
	end
end

function WorldSmithUtilities.AnimateDoor(parameters, dir, remoteEvent, player, container)
	if container.Enabled.Value == true then
		container.Enabled.Value = false
		remoteEvent:FireAllClients(player, parameters, dir)
		wait(parameters.Time + parameters.CloseDelay)
		container.Enabled.Value = true
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

function WorldSmithUtilities.Vehicle(parameters, argType, remoteEvent, player, container)
	if argType == "enterVehicle" then
		local motor6d = Instance.new("Weld")
		player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
		player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		player.Character.HumanoidRootPart.CFrame = parameters.DriverConstraint.Parent.CFrame
		container.MainPart.Value:SetNetworkOwner(player)
		motor6d.Part0 = player.Character.HumanoidRootPart
		motor6d.Part1 = parameters.DriverConstraint.Parent
		motor6d.Parent = player.Character.HumanoidRootPart
		remoteEvent:FireClient(player, player, WorldSmithUtilities.CreateArgDictionary(container:GetChildren()), argType)
	elseif argType == "exitVehicle" then
		player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		container.EnterTrigger.Value.Enabled.Value = true
		parameters._totalOccupants = parameters._totalOccupants - 1
		repeat wait() until container.MainPart.Value.Velocity.magnitude < 0.1
		container.MainPart.Value:SetNetworkOwner(nil)
	end
end

function WorldSmithUtilities.ConstrainCharacter(player, container)
	player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
	player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	player.Character.HumanoidRootPart.CFrame = container.Parent.CFrame
	container.Enabled.Value = false
end

function WorldSmithUtilities.GetTriggerEventNames(triggerObj)
	local objName = (triggerObj:FindFirstChild("Event") and "Event") or (triggerObj:FindFirstChild("RemoteEvent") and "RemoteEvent")
	local eventName = (triggerObj:FindFirstChild("Event") and "Event") or (triggerObj:FindFirstChild("RemoteEvent") and "OnServerEvent")
	return objName, eventName
end

return WorldSmithUtilities
