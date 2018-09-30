local WorldSmithUtilities = {}

local clientSideActiveWorldObjects = {}
local clientSideAssignedWorldObjects = {}

function WorldSmithUtilities.AnimatedDoor(parameters, dir, worldObjectRef)
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
			TweenInfo.new(parameters.Time/2, Enum.EasingStyle[parameters.EasingStyle] or Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, parameters.CloseDelay or 0),
			{CFrame = cf2}
		)
		tween2:Play()
		wait((parameters.Time / 2) + parameters.CloseDelay)
		clientSideActiveWorldObjects[worldObjectRef] = nil
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

return WorldSmithUtilities
