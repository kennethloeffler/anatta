local CollectionService = game:GetService("CollectionService")

local WorldSmithClientMain = {}
WorldSmithClientMain.__index = WorldSmithClientMain

local function createArgDictionary(paramContainerChildren)
	local t = {}
	local c = paramContainerChildren
	for i, v in ipairs(c) do
		if v:IsA("ValueBase") then
			t[v.Name] = v.Value
		end
	end
	return t
end

local clientSideActiveWorldObjects = {}

local clientSideAssignedWorldObjects = {}

local func = {
	AnimatedDoor = function(parameters, dir, worldObjectRef)
		if not clientSideActiveWorldObjects[worldObjectRef] then
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
				TweenInfo.new(parameters.Time/2, Enum.EasingStyle[parameters.EasingStyle] or Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, parameters.CloseDelay or 0),
				{CFrame = cf2}
			)
			tween2:Play()
			wait((parameters.Time / 2) + parameters.CloseDelay)
			clientSideActiveWorldObjects[worldObjectRef] = nil
		end
	end
}

local clientPredictionFunc = {
	AnimatedDoor = function(parameters, worldObjectRef)
		game.Players.LocalPlayer.Character.HumanoidRootPart.Touched:connect(function(part)
			if parameters.Enabled then
				if part == parameters.FrontTrigger then
					func.AnimatedDoor(parameters, 1, worldObjectRef)
				elseif part == parameters.BackTrigger then
					func.AnimatedDoor(parameters, -1, worldObjectRef)
				end
			end
		end)
	end
}

function WorldSmithClientMain.new()
	
	local instance = setmetatable({}, WorldSmithClientMain)
	
	while wait(2) do
		local worldObjects = CollectionService:GetTagged("WorldObject")
		for _, worldObject in pairs(worldObjects) do
			if not clientSideAssignedWorldObjects[worldObject] then
				clientSideAssignedWorldObjects[worldObject] = true
				for _, container in pairs(worldObject:GetChildren()) do
					local worldObject = container.Name
					if container:IsA("Folder") then
						for _, obj in pairs(container:GetChildren()) do
							if obj:IsA("RemoteEvent") then
								obj.OnClientEvent:connect(function(player, parameters, dir)
									if player ~= game.Players.LocalPlayer then
										print(player.Name)
										func[worldObject](parameters, dir, container)
									end
								end)
								clientPredictionFunc[worldObject](createArgDictionary(container:GetChildren()), container)
							end
						end
					end
				end
			end
		end
	end
		
	return instance
end


return WorldSmithClientMain.new()
