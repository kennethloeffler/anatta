local WorldSmithUtilities = require(script.Parent.WorldSmithServerUtilities)

local WorldObjectData = {
	FoodItem = {
		BurgerPatty = {
			Price = 0			
		}
	}
}

ComponentInfo = {
	["ContextActionTrigger"] = {
		Enabled = "boolean",
		desktopPC = "string",
		mobile = "string",
		console = "string",
		MaxDistance = "number",
		CreateTouchButton = "boolean",
		["_init"] = function(parameters, container)
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Parent = container
			local bindableEvent = Instance.new("BindableEvent")
			bindableEvent.Parent = container
		end,
	},
	["CharacterConstraint"] = {
		CharacterPoseId = "number",
		Enabled = "boolean",
		Label = "string"
	},
	["TouchTrigger"] = {
		Enabled = "boolean",
		["_init"] = function(parameters, container)
			if container.Parent:IsA("BasePart") then
				local bindableEvent = Instance.new("BindableEvent")
				bindableEvent.Parent = container
			end
		end,
		["_connectEventsFunction"] = function(parameters, container)
			if container.Parent:IsA("BasePart") then
				container.Parent.Touched:connect(function(part)
					if container.Enabled.Value == true then
						container.Event:Fire(part)
					end
				end)
			end
		end
	},
	["DestroyWhenIdle"] = {
		MaximumIdleTime = "number",
		Trigger = "Instance",
		["_connectEventsFunction"] = function(parameters, container)
			local startedThread = false
			local t = 0
			container.Trigger.Value.RemoteEvent.OnServerEvent:connect(function()
				t = 0
				if not startedThread then
					startedThread = true
					spawn(function()
						while wait(1) do
							if container.Trigger.Value.Enabled.Value == true then 
								t = t + 1 
							end
							if t >= container.MaximumIdleTime.Value then 
								container.Parent:Destroy()
								break 
							end
						end
					end)
				end
			end)
		end
	},
	["AutoSpawner"] = {
		Enabled = "boolean",
		RespawnTime = "number",
		MaxSpawnedItems = "number",
		ItemToSpawn = "Instance",
		["_init"] = function(parameters, container)
			local bindableEvent = Instance.new("BindableEvent", container)
		end,
		["_connectEventsFunction"] = function(parameters, container)
			if container.Parent:IsA("BasePart") then
				local part = container.Parent
				local partSize = part.Size
				local partPos = part.CFrame.p
				local region3 = Region3.new((part.CFrame * CFrame.new(-partSize / 2)).p, (part.CFrame * CFrame.new(partSize / 2)).p)
				local spawnedItem = container.ItemToSpawn.Value
				local flag = Instance.new("BoolValue", spawnedItem)
				flag.Name = "CLONE"
				part.Anchored = true
				local itemToSpawn = spawnedItem:Clone()
				spawn(function()
					local totalSpawnedItems = 0
					while wait(1) do
						local pos = spawnedItem:IsA("Model") and spawnedItem:GetPrimaryPartCFrame().p or spawnedItem.CFrame.p
						local shouldRespawn = container.MaxSpawnedItems.Value < 0 and true or totalSpawnedItems < container.MaxSpawnedItems.Value
						if (pos - partPos).magnitude > (partSize / 2).magnitude and shouldRespawn then
							wait(container.RespawnTime.Value)
							totalSpawnedItems = totalSpawnedItems + 1
							itemToSpawn.Parent = game.Workspace
							spawnedItem = itemToSpawn
							itemToSpawn = itemToSpawn:Clone()
							container.Event:Fire()
						end
					end
				end)
			end
		end
	},
	["TimedRespawner"] = {
		Enabled = "boolean",
		RespawnTime = "number",
		ItemToSpawn = "Instance",
		DestroyLastItem = "boolean",
		["_init"] = function(parameters, container)
			local bindableEvent = Instance.new("BindableEvent", container)
		end,
		["_connectEventsFunction"] = function(parameters, container)
			local obj = container.ItemToSpawn.Value:Clone()
			spawn(function()
				while wait(container.RespawnTime.Value) do
					if container.Enabled.Value == true then
						if container.DestroyLastItem.Value == true then container.ItemToSpawn.Value:Destroy() end
						container.ItemToSpawn.Value = obj
						local flag = Instance.new("BoolValue", obj)
						flag.Name = "CLONE"
						obj.Parent = game.Workspace
						obj = obj:Clone()
						container.Event:Fire()
					end
				end
			end)
		end
	},
	["TweenPartPosition"] = {
		Enabled = "boolean",
		LocalCoords = "boolean",
		ClientSide = "boolean",
		Trigger = "Instance",
		Time = "number",
		EasingStyle = "string",
		EasingDirection = "string",
		Reverses = "boolean",
		RepeatCount = "number",
		DelayTime = "number",
		X = "number",
		Y = "number",
		Z = "number",
		["_init"] = function(parameters, container)
			local remoteEvent = Instance.new("RemoteEvent", container)
		end,
		["_connectEventsFunction"] = function(parameters, container)
			if container.Trigger.Value then
				if not container.ClientSide.Value then
					if container.Trigger.Value:FindFirstChild("RemoteEvent") then
						container.Trigger.Value.RemoteEvent.OnServerEvent:connect(function()
							container.RemoteEvent:FireAllClients()
						end)
					end
					if container.Trigger.Value:FindFirstChild("Event") then
						container.Trigger.Value.Event.Event:connect(function()
							container.RemoteEvent:FireAllClients()
						end)
					end
				end
			end
		end
	},
	["TweenPartRotation"] = {
		Enabled = "boolean",
		ClientSide = "boolean",
		LocalCoords = "boolean",
		Trigger = "Instance",
		Time = "number",
		EasingStyle = "string",
		EasingDirection = "string",
		Reverses = "boolean",
		RepeatCount = "number",
		DelayTime = "number",
		X = "number",
		Y = "number",
		Z = "number",
		["_init"] = function(parameters, container)
			local remoteEvent = Instance.new("RemoteEvent", container)
		end,
		["_connectEventsFunction"] = function(parameters, container)
			if container.Trigger.Value then
				if not container.ClientSide.Value then
					if container.Trigger.Value:FindFirstChild("RemoteEvent") then
						container.Trigger.Value.RemoteEvent.OnServerEvent:connect(function()
							container.RemoteEvent:FireAllClients()
						end)
					end
					if container.Trigger.Value:FindFirstChild("Event") then
						container.Trigger.Value.Event.Event:connect(function()
							container.RemoteEvent:FireAllClients()
						end)
					end
				end
			end
		end
	},
	["StoreFoodItem"] = {
		FoodName = "string",
		FoodPrice = "number",
		["_init"] = function(parameters, container)
								
		end,
		["_connectEventsFunction"] = function(parameters, container)
			
		end
	},
	["ShoppingCart"] = {
		MaxCapacity = "number",
	},
	["StoreCheckout"] = {
		
	},
	["AnimatedDoor"] = {
		Enabled = "boolean",
		AutomaticTriggers = "boolean",
		Time = "number",
		OpenDirection = "number",
		CloseDelay = "number",
		EasingStyle = "string",
		TriggerOffset = "number",
		PivotPart = "Instance",
		FrontTrigger = "Instance",
		BackTrigger = "Instance",
		["_init"] = function(parameters, container)
			if parameters.PivotPart.Parent:IsA("Model") then
				for _, part in pairs(parameters.PivotPart.Parent:GetChildren()) do
					if part ~= parameters.PivotPart and part:IsA("BasePart") then
						local motor6d = Instance.new("Motor6D")
						motor6d.Parent = part
						motor6d.C0 = part.CFrame:inverse() * parameters.PivotPart.CFrame
						motor6d.Part0 = part
						motor6d.Part1 = parameters.PivotPart
						part.Anchored = false
					end
				end
				if parameters.AutomaticTriggers == true then
					local modelSize = parameters.PivotPart.Parent:GetModelSize()
					local pivotSize = parameters.PivotPart.Size
					local frontTrigger = WorldSmithUtilities.CreateTouchTrigger(parameters.PivotPart.CFrame * CFrame.new(modelSize.X/2 - pivotSize.X/2, 0, 1 + parameters.TriggerOffset), Vector3.new(modelSize.X, modelSize.Y, 1), container, "FrontTrigger")
					local backTrigger = WorldSmithUtilities.CreateTouchTrigger(parameters.PivotPart.CFrame * CFrame.new(modelSize.X/2 - pivotSize.X/2, 0, -1 - parameters.TriggerOffset), Vector3.new(modelSize.X, modelSize.Y, 1), container, "BackTrigger")

				end
				parameters.PivotPart.Anchored = true
				local remoteEvent = Instance.new("RemoteEvent")
				remoteEvent.Parent = container
			end
		end,
		["_connectEventsFunction"] = function(parameters, container)
			local frontDirection = parameters.OpenDirection == 0 and 1 or parameters.OpenDirection
			local backDirection = parameters.OpenDirection == 0 and -1 or parameters.OpenDirection
			local frontEventObj, frontEventName = WorldSmithUtilities.GetTriggerEventNames(parameters.FrontTrigger)
			parameters.FrontTrigger[frontEventObj][frontEventName]:connect(function(part)
				local player = game.Players:GetPlayerFromCharacter(part.Parent)
				if part.Parent:FindFirstChild("Humanoid") or part:IsA("Player") then
					WorldSmithUtilities.AnimateDoor(parameters, frontDirection, container.RemoteEvent, player, container)
				end
			end)
			local backEventObj, backEventName = WorldSmithUtilities.GetTriggerEventNames(parameters.BackTrigger)
			parameters.BackTrigger[backEventObj][backEventName]:connect(function(part)
				local player = game.Players:GetPlayerFromCharacter(part.Parent) or part
				if part.Parent:FindFirstChild("Humanoid") or part:IsA("Player") then
					WorldSmithUtilities.AnimateDoor(parameters, backDirection, container.RemoteEvent, player, container)
				end
			end)
		end
	},
	["Vehicle"] = {
		Enabled = "boolean",
		CameraFollowsVehicle = "boolean",
		MainPart = "Instance",
		AutoTrigger = "boolean",
		EnterTrigger = "Instance",
		AccelerationRate = "number",
		BrakeDeceleration = "number",
		MaxTurnSpeed = "number",
		TurnRate = "number",
		MaxSpeed = "number",
		MaxForce = "number",
		WheelContainer = "Instance",
		DriverConstraint = "Instance",
		AdditionalCharacterConstraints = "Instance",
		_totalOccupants = "number",
		["_init"] = function(parameters, container)
			local remoteEvent = Instance.new("RemoteEvent", container)
			--[[local bodyForce = Instance.new("BodyVelocity", parameters.MainPart)
			local bodyGyro = Instance.new("BodyGyro", parameters.MainPart)
			bodyForce.Name = "BodyVelocity"
			bodyForce.MaxForce = Vector3.new(math.huge, 0, math.huge)
			bodyForce.Velocity = Vector3.new(0, 0, 0)
			bodyGyro.Name = "BodyGyro"
			bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			bodyGyro.CFrame = parameters.MainPart.CFrame--]]
			for _, part in pairs(container.Parent:GetChildren()) do
				if part:IsA("BasePart") then
					local motor6d = Instance.new("Motor6D")
					motor6d.Parent = part
					motor6d.C0 = part.CFrame:inverse() * parameters.MainPart.CFrame
					motor6d.Part0 = part
					motor6d.Part1 = parameters.MainPart
					part.Anchored = false
				elseif part:IsA("Model") and part ~= parameters.WheelContainer then
					for _, subPart in pairs(part:GetChildren()) do
						local motor6d = Instance.new("Motor6D")
						motor6d.Parent = subPart
						motor6d.C0 = subPart.CFrame:inverse() * parameters.MainPart.CFrame
						motor6d.Part0 = subPart
						motor6d.Part1 = parameters.MainPart
						subPart.Anchored = false
					end
				end
			end
			parameters.MainPart.Anchored = false
		end,
		["_connectEventsFunction"] = function(parameters, container)
			if parameters.EnterTrigger then
				local eventObj, eventName = WorldSmithUtilities.GetTriggerEventNames(parameters.EnterTrigger)
				parameters.EnterTrigger.RemoteEvent.OnServerEvent:connect(function(arg)
					local maxCapacity = (parameters.AdditionalCharacterContraints and #container.AdditionalCharacterConstraints.Value:GetChildren() or 0) + 1
					if container.EnterTrigger.Value.Enabled.Value == true and parameters._totalOccupants <= maxCapacity then
						local player = game.Players:GetPlayerFromCharacter(arg.Parent) or arg
						WorldSmithUtilities.ConstrainCharacter(player, parameters.DriverConstraint)
						parameters._totalOccupants = parameters._totalOccupants + 1
						WorldSmithUtilities.Vehicle(parameters, "enterVehicle", container.RemoteEvent, player, container)
						if parameters._totalOccupants == maxCapacity then
							container.EnterTrigger.Value.Enabled.Value = false
						end
					end
				end)
			end
			if not parameters.EnterTrigger and parameters.AutoTrigger == true then
				-- TODO: setup auto context action trigger
			end
			container.RemoteEvent.OnServerEvent:connect(function(player, argType, arg)
				if argType == "exitVehicle" then
					WorldSmithUtilities.Vehicle(parameters, "exitVehicle", container.RemoteEvent, player, container)
				end
			end)
		end
	},
}



return ComponentInfo
