local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")

local Utilities = require(script.Parent:WaitForChild("WorldSmithClientUtilities"))

local WorldSmithClientMain = {}
WorldSmithClientMain.__index = WorldSmithClientMain

TotalContextActions = 0

local clientPredictionFunc = {
	AnimatedDoor = function(parameters, worldObjectRef)
		parameters.FrontTrigger.Event.Event:connect(function(part)
			local frontDirection = Utilities.QueryWorldObject(worldObjectRef, "OpenDirection") == 0 and 1 or Utilities.QueryWorldObject(worldObjectRef, "OpenDirection")
			if parameters.Enabled == true then
				Utilities.AnimatedDoor(parameters, frontDirection, worldObjectRef)
			end
		end)
		parameters.BackTrigger.Event.Event:connect(function(part)
			local backDirection = Utilities.QueryWorldObject(worldObjectRef, "OpenDirection") == 0 and -1 or Utilities.QueryWorldObject(worldObjectRef, "OpenDirection")
			if parameters.Enabled == true then
				Utilities.AnimatedDoor(parameters, backDirection, worldObjectRef)
			end
		end)
	end,
	TouchTrigger = function(parameters, worldObjectRef)
		worldObjectRef.Parent.Touched:connect(function(part)
			if Utilities.QueryWorldObject(worldObjectRef, "Enabled") == true and part.Parent == game.Players.LocalPlayer.Character then
				worldObjectRef.Event:Fire()
			end
		end)
	end,
	ContextActionTrigger = function(parameters, worldObjectRef)
		local function contextActionFunction(actionName, inputState, inputObj)
			if inputState == Enum.UserInputState.Begin then
				worldObjectRef.Event:Fire()
				worldObjectRef.RemoteEvent:FireServer()
			end
		end
		if worldObjectRef.Parent:IsA("BasePart") then
			TotalContextActions = TotalContextActions + 1
			local num = TotalContextActions .. TotalContextActions
			spawn(function()
				while wait() do -- TODO: add ContextAction ui
					if (worldObjectRef.Parent.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= Utilities.QueryWorldObject(worldObjectRef, "MaxDistance") then
						ContextActionService:BindAction(num, contextActionFunction, false, Enum[Utilities.QueryWorldObject(worldObjectRef, "InputEnum")][Utilities.QueryWorldObject(worldObjectRef, "InputType")])
					else
						ContextActionService:UnbindAction(num)
					end
				end
			end)
		end
	end,
	Vehicle = function(parameters, worldObjectRef)
		worldObjectRef.RemoteEvent.OnClientEvent:connect(function(argType, occupantNumber)
			game.Players.LocalPlayer.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
			game.Players.LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = occupantNumber == 1 and parameters.DriverConstraint.Parent.CFrame or parameters.AdditionalCharacterConstraints[tostring(occupantNumber)].CFrame
			local motor6d = Instance.new("Weld")
			motor6d.Part0 = game.Players.LocalPlayer.Character.HumanoidRootPart
			motor6d.Part1 = occupantNumber == 1 and parameters.DriverConstraint.Parent or parameters.AdditionalCharacterConstraints[tostring(occupantNumber)]
			motor6d.Parent = game.Players.LocalPlayer.Character.HumanoidRootPart
		end)
	end,
	CharacterConstraint = function()
		
	end
}

function WorldSmithClientMain.new()
	
	local self = setmetatable({}, WorldSmithClientMain)
	
	repeat wait() until game:IsLoaded() == true
	self:_setupEntityComponentMap()
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
							if player ~= game.Players.LocalPlayer and Utilities[component.Name] then
								Utilities[component.Name](parameters, arg, component)
							end
						end)
					end
				end
				clientPredictionFunc[component.Name](Utilities.CreateArgDictionary(component:GetChildren()), component)
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
									Utilities[component.Name](parameters, arg, component)
								end
							end)
						end
					end
					clientPredictionFunc[component.Name](Utilities.CreateArgDictionary(component:GetChildren()), component)
				end
			end
		end
	end
end


return WorldSmithClientMain.new()
