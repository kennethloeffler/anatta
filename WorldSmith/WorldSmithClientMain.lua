local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")

local WorldSmithClientMain = {}
WorldSmithClientMain.__index = WorldSmithClientMain

TotalContextActions = 0

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

local function queryWorldObject(worldObjectRef, param)
	if worldObjectRef[param] then
		return worldObjectRef[param].Value
	else
		error("WorldObject '".. worldObjectRef.Name .. "' does not have parameter '" .. param .. "'")
	end
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
				TweenInfo.new(parameters.Time/2, Enum.EasingStyle[parameters.EasingStyle] or Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, parameters.CloseDelay or 0),
				{CFrame = cf2}
			)
			tween2:Play()
			wait((parameters.Time / 2) + parameters.CloseDelay)
			clientSideActiveWorldObjects[worldObjectRef] = nil
		end
	end,
}

local clientPredictionFunc = {
	AnimatedDoor = function(parameters, worldObjectRef)
		parameters.FrontTrigger.Event.Event:connect(function(part)
			local frontDirection = queryWorldObject(worldObjectRef, "OpenDirection") == 0 and 1 or queryWorldObject(worldObjectRef, "OpenDirection")
			if parameters.Enabled == true then
				func.AnimatedDoor(parameters, frontDirection, worldObjectRef)
			end
		end)
		parameters.BackTrigger.Event.Event:connect(function(part)
			local backDirection = queryWorldObject(worldObjectRef, "OpenDirection") == 0 and -1 or queryWorldObject(worldObjectRef, "OpenDirection")
			if parameters.Enabled == true then
				func.AnimatedDoor(parameters, backDirection, worldObjectRef)
			end
		end)
	end,
	TouchTrigger = function(parameters, worldObjectRef)
		worldObjectRef.Parent.Touched:connect(function(part)
			if queryWorldObject(worldObjectRef, "Enabled") == true and part.Parent == game.Players.LocalPlayer.Character then
				worldObjectRef.Event:Fire()
			end
		end)
	end,
	ContextActionTrigger = function(parameters, worldObjectRef)
		local function contextActionFunction(actionName, inputState, inputObj)
			if inputState == Enum.UserInputState.Begin then
				worldObjectRef.RemoteEvent:FireServer()
			end
		end
		if worldObjectRef.Parent:IsA("BasePart") then
			TotalContextActions = TotalContextActions + 1
			local num = TotalContextActions .. TotalContextActions
			spawn(function()
				while wait() do
					if (worldObjectRef.Parent.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= queryWorldObject(worldObjectRef, "MaxDistance") then
						ContextActionService:BindAction(num, contextActionFunction, false, Enum[queryWorldObject(worldObjectRef, "InputEnum")][queryWorldObject(worldObjectRef, "InputType")])
					else
						ContextActionService:UnbindAction(num)
					end
				end
			end)
		end
	end
}

function WorldSmithClientMain.new()
	
	local self = setmetatable({}, WorldSmithClientMain)
	
	self:_setupEntityComponentMap()
	repeat wait() until game.Players.LocalPlayer.Character ~= nil
	self:_refreshEntityComponentMap()
	
	return self
end

function WorldSmithClientMain:_setupEntityComponentMap()
	
	self._registeredSystems = {}
	self._entityComponentMap = {}

	CollectionService:GetInstanceAddedSignal("entity"):connect(function(entity)
		self._entityComponentMap[entity] = {}
	end)
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		if not self._registeredSystems[component] then
			self._registeredSystems[component] = true
			if self._entityComponentMap[component.Parent] then
				self._entityComponentMap[component.Parent][#self._entityComponentMap[component.Parent] + 1] = component
				for _, obj in pairs(component:GetChildren()) do
					if obj:IsA("RemoteEvent") then
						obj.OnClientEvent:connect(function(player, parameters, arg)
							if player ~= game.Players.LocalPlayer and func[component.Name] then
								func[component.Name](parameters, arg, component)
							end
						end)
					end
				end
				clientPredictionFunc[component.Name](createArgDictionary(component:GetChildren()), component)
			else
				error("WorldSmith: this error should never happen")
			end
		end
	end)
	
	local assignedInstances = CollectionService:GetTagged("entity")
	local worldObjectTags = CollectionService:GetTagged("component")
	for _, entity in pairs(assignedInstances) do
		for _, component in pairs(worldObjectTags) do
			if component.Parent == entity then
				if self._entityComponentMap[entity] == nil then 
					self._entityComponentMap[entity] = {}
				end
				self._entityComponentMap[entity][#self._entityComponentMap[entity] + 1] = component
			end
		end
	end

end

function WorldSmithClientMain:_refreshEntityComponentMap()
	for entity, componentList in pairs(self._entityComponentMap) do
		if entity.Parent then
			for _, component in ipairs(componentList) do
				if not self._registeredSystems[component] then
					self._registeredSystems[component] = true
					for _, obj in pairs(component:GetChildren()) do
						if obj:IsA("RemoteEvent") then
							obj.OnClientEvent:connect(function(player, parameters, arg)
								if player ~= game.Players.LocalPlayer then
									print(player.Name)
									func[component.Name](parameters, arg, component)
								end
							end)
						end
					end
					clientPredictionFunc[component.Name](createArgDictionary(component:GetChildren()), component)
				end
			end
		end
	end
end--]]


return WorldSmithClientMain.new()
