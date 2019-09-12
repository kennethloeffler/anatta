local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSrc = ReplicatedStorage:WaitForChild("WorldSmith")
local PluginSrc = script.Parent.Parent.Parent.src

local Sandbox = require(script.Parent.Parent.SandboxEnv)
local Serial = require(script.Parent.Parent.Serial)
local WSAssert = require(PluginSrc.WSAssert)

local NumUniqueComponents = 0
local ComponentsArray = {}
local GameComponentDefs = {}

local ComponentsLoader = {}
local WatchedModules = {}

local function tryRequire(moduleScript)
	local env = Sandbox.new(moduleScript)
	local success, result = xpcall(function()
		return env.require(moduleScript)
	end,

	function(err)
		return err
	end)

	WSAssert(success, "tried to load component definition module: " .. moduleScript:GetFullName())

	return result
end

-- this function is probably too big but w/e
local function tryCollectComponent(instance)

	if not instance:IsA("ModuleScript") or instance.Name == "Component" then
		return
	end

	local pattern = "Component%.Define%("

	if instance.Source:match(pattern) then
		local rawComponent = tryRequire(instance)
		local componentType = rawComponent[1]
		local paramMap = rawComponent[2]

		if GameComponentDefs[componentType] then
			-- component definition has already been serialized; check if we have any new or removed params
			local newParams = {}
			local oldParamArray = {}
			local indicesToFill = {}
			local currentIndex = 0
			local numOldParams = 0
			local maxParamIndex = 0

			-- remove params that aren't in paramMap
			for paramName in pairs(GameComponentDefs[componentType]) do
				if not paramMap[paramName] and paramName ~= "ComponentId" then
					GameComponentDefs[componentType][paramName] = nil
				end
			end

			for paramName, defaultValue in pairs(paramMap) do

				local paramId = GameComponentDefs[componentType][paramName][1]
				if not paramId then
					newParams[paramName] = defaultValue
				else
					numOldParams = numOldParams + 1
					oldParamArray[paramId] = true
					maxParamIndex = paramId > maxParamIndex and paramId or maxParamIndex
				end
			end

			-- check for holes
			for i = 1, numOldParams do
				if not oldParamArray[i] then
					indicesToFill[#indicesToFill + 1] = i
				end
			end

			-- add new params and fill any holes
			for paramName, defaultValue in pairs(newParams) do
				currentIndex = currentIndex + 1
				if indicesToFill[currentIndex] then
					GameComponentDefs[componentType][paramName] = {indicesToFill[currentIndex], defaultValue}
				else
					maxParamIndex = maxParamIndex + 1
					GameComponentDefs[componentType][paramName] = {maxParamIndex, defaultValue}
				end
			end

			return
		end

		-- this component has not been serialized before
		local componentIdListHole
		local componentId
		local paramId = 0

		for i = 1, NumUniqueComponents do
			if not ComponentsArray[i] then
				print("found hole")
				componentIdListHole = i
				break
			end
		end

		NumUniqueComponents = NumUniqueComponents + 1
		GameComponentDefs[componentType] = {}

		if not componentIdListHole then
			componentId = NumUniqueComponents
		else
			componentId = componentIdListHole
		end

		GameComponentDefs[componentType].ComponentId = componentId
		ComponentsArray[componentId] = componentType

		for paramName, defaultValue in pairs(paramMap) do
			paramId = paramId + 1
			GameComponentDefs[componentType][paramName] = {paramId, defaultValue}
		end
	end
end

function tryRemoveComponent(instance)

	if not instance:IsA("ModuleScript") or instance.Name == "Component" then
		return
	end

	local pattern = "Component%.Define%("
	if instance.Source:match(pattern) then
		local rawComponent = tryRequire(instance)
		local componentType = rawComponent[1]

		GameComponentDefs[componentType] = nil

		for componentId, comtype in pairs(ComponentsArray) do
			if comtype == componentType then
				ComponentsArray[componentId] = nil
				break
			end
		end

		NumUniqueComponents = NumUniqueComponents - 1
	end
end

function ComponentsLoader.OnLoaded(plugin)

	local GameComponentDefModule = GameSrc.ComponentDesc:WaitForChild("ComponentDefinitions", 1)

	if GameComponentDefModule then
		for componentType, componentDef in pairs(require(GameComponentDefModule)) do
			GameComponentDefs[componentType] = componentDef
			GameComponentDefs[componentType].ComponentId = componentDef.ComponentId
			ComponentsArray[componentDef.ComponentId] = componentType
			NumUniqueComponents = NumUniqueComponents + 1
		end
	else
		GameComponentDefModule = Instance.new("ModuleScript")
	end

	for _, inst in pairs(ReplicatedStorage:GetDescendants()) do
		tryCollectComponent(inst)
	end

	GameComponentDefModule.Source = Serial.Serialize(GameComponentDefs)
	GameComponentDefModule.Name = "ComponentDefinitions"
	GameComponentDefModule.Parent = GameSrc.ComponentDesc

	ReplicatedStorage.DescendantAdded:Connect(function(inst)
		tryCollectComponent(inst)
		GameComponentDefModule.Source = Serial.Serialize(GameComponentDefs)
	end)

	ReplicatedStorage.DescendantRemoving:Connect(function(inst)
		tryRemoveComponent(inst)
		GameComponentDefModule.Source = Serial.Serialize(GameComponentDefs)
	end)
end

return ComponentsLoader

