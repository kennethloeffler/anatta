local WorldObject = require(script.Parent.Component)

local WorldSmithUtilities = {}

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

function WorldSmithUtilities.ConstrainCharacter(player, container)
	local motor6d = Instance.new("Weld")
	player.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
	player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	player.Character.HumanoidRootPart.CFrame = container.Parent.CFrame
	motor6d.Part0 = player.Character.HumanoidRootPart
	motor6d.Part1 = container.Parent
	motor6d.Name = "CharacterConstraint"
	motor6d.Parent = player.Character.HumanoidRootPart
	container.Enabled.Value = false
end

function WorldSmithUtilities.GetTriggerEventNames(triggerObj)
	local objName = (triggerObj:FindFirstChild("Event") and "Event") or (triggerObj:FindFirstChild("RemoteEvent") and "RemoteEvent")
	local eventName = (triggerObj:FindFirstChild("Event") and "Event") or (triggerObj:FindFirstChild("RemoteEvent") and "OnServerEvent")
	return objName, eventName
end

return WorldSmithUtilities
