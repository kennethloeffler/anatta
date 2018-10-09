local CollectionService = game:GetService("CollectionService")
local Utilities = require(script.WorldSmithClientUtilities)

local WorldSmithClientMain = {}
WorldSmithClientMain.__index = WorldSmithClientMain

local clientPredictionFunc = {
	TweenPartPosition = function(parameters, componentRef)
		if componentRef.Trigger.Value then
			if componentRef.Trigger.Value:FindFirstChild("Event") then
				componentRef.Trigger.Value.Event.Event:connect(function()
					Utilities.TweenPartPosition(parameters, nil, componentRef)
				end)
			end
		end
	end,
	TweenPartRotation = function(parameters, componentRef)
		if componentRef.Trigger.Value then
			if componentRef.Trigger.Value:FindFirstChild("Event") then
				componentRef.Trigger.Value.Event.Event:connect(function()
					Utilities.TweenPartRotation(parameters, nil, componentRef)
				end)
			end
		end
	end,
	TouchTrigger = function(parameters, componentRef)
		componentRef.Parent.Touched:connect(function(part)
			if Utilities.Query(componentRef, "Enabled") == true and part.Parent == game.Players.LocalPlayer.Character then
				componentRef.Event:Fire()
			end
		end)
	end,
	AnimatedDoor = function(parameters, componentRef)
		parameters.FrontTrigger.Event.Event:connect(function(part)
			local frontDirection = Utilities.Query(componentRef, "OpenDirection") == 0 and 1 or Utilities.Query(componentRef, "OpenDirection")
			if parameters.Enabled == true then
				Utilities.AnimatedDoor(parameters, frontDirection, componentRef)
			end
		end)
		parameters.BackTrigger.Event.Event:connect(function(part)
			local backDirection = Utilities.Query(componentRef, "OpenDirection") == 0 and -1 or Utilities.Query(componentRef, "OpenDirection")
			if parameters.Enabled == true then
				Utilities.AnimatedDoor(parameters, backDirection, componentRef)
			end
		end)
	end,
}

function WorldSmithClientMain.new()
	
	local self = setmetatable({}, WorldSmithClientMain)
	
	repeat wait() until game:IsLoaded() == true
	
	self:_setupEntityComponentMap()
	self:_refreshEntityComponentMap()
	self:_initializeSystems()
	
	return self
end

function WorldSmithClientMain:_setupEntityComponentMap()
	print("WorldSmithClientMain: building entity component map...")
	local mapBuildTime = tick()
	
	self._registeredSystems = {}
	self._entityComponentMap = {}
	self._componentEntityMap = {}

	CollectionService:GetInstanceAddedSignal("entity"):connect(function(entity)
		self._entityComponentMap[entity] = {}
	end)
	
	CollectionService:GetInstanceAddedSignal("component"):connect(function(component)
		if not self._registeredSystems[component] then
			self._registeredSystems[component] = true
			if self._componentEntityMap[component.Name] == nil then 
				self._componentEntityMap[component.Name] = {}
			end
			Utilities.YieldUntilComponentLoaded(component)
			if self._entityComponentMap[component.Parent] then
				self._entityComponentMap[component.Parent][#self._entityComponentMap[component.Parent] + 1] = component
				self._componentEntityMap[component.Name][component.Parent] = true
				for _, obj in pairs(component:GetChildren()) do
					if obj:IsA("RemoteEvent") then
						obj.OnClientEvent:connect(function(player, parameters, arg)
							if Utilities[component.Name] then
								Utilities[component.Name](parameters, arg, component)
							end
						end)
					end
				end
				if clientPredictionFunc[component.Name] then
					clientPredictionFunc[component.Name](Utilities.CreateArgDictionary(component:GetChildren()), component)
				end
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
				if self._componentEntityMap[component.Name] == nil then 
					self._componentEntityMap[component.Name] = {}
				end
				self._entityComponentMap[entity][#self._entityComponentMap[entity] + 1] = component
				self._componentEntityMap[component.Name][entity] = true
			end
		end
	end
	print("WorldSmithClientMain: took " .. tick() - mapBuildTime .. " seconds to build")
end

function WorldSmithClientMain:_refreshEntityComponentMap()
	print("WorldSmithClientMain: connecting clientside component events...")
	local mapBuildTime = tick()
	for entity, componentList in pairs(self._entityComponentMap) do
		if entity.Parent then
			for _, component in ipairs(componentList) do
				if not self._registeredSystems[component] then
					self._registeredSystems[component] = true
					spawn(function()
						Utilities.YieldUntilComponentLoaded(component)
						for _, obj in pairs(component:GetChildren()) do
							if obj:IsA("RemoteEvent") then
								obj.OnClientEvent:connect(function(player, parameters, arg)
									if Utilities[component.Name] then
										Utilities[component.Name](parameters, arg, component, player)
									end
								end)
							end
						end
						if clientPredictionFunc[component.Name] then
							clientPredictionFunc[component.Name](Utilities.CreateArgDictionary(component:GetChildren()), component)
						end
					end)
				end
			end
		end
	end
	print("WorldSmithClientMain: took " .. tick() - mapBuildTime .. " seconds to build")
end

function WorldSmithClientMain:_initializeSystems()
	print("WorldSmithClientMain: initialzing clientside systems...")
	local mapBuildTime = tick()
	for _, system in pairs(script.Systems:GetChildren()) do
		local sys = require(system)
		coroutine.resume(coroutine.create(sys.Start), self._componentEntityMap)
	end
	print("WorldSmithClientMain: took " .. tick() - mapBuildTime .. " seconds to build")
end


return WorldSmithClientMain.new()
