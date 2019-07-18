local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSrc = ReplicatedStorage:WaitForChild("WorldSmith")
local PluginSrc = script.Parent.Parent.Parent.src

local GameComponentDesc = GameSrc and require(GameSrc.ComponentDesc)
local Sandbox = require(script.Parent.Parent.SandboxEnv)
local Serial = require(script.Parent.Parent.Serial)
local WSAssert = require(PluginSrc.WSAssert)

local NumUniqueComponents = 0
local ComponentsArray = {}
local GameComponentDefs = {}

local ComponentsLoader = {}

local function tryRequire(moduleScript)
	local env = Sandbox.new(moduleScript)
	local success, result = xpcall(function()
		return env.require(moduleScript)
	end,
	function(err)
		return err
	end)

	WSAssert(success, "tried to load component definition module: " .. result)

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
				if not paramMap[paramName] then
					GameComponentDefs[componentType][paramName] = nil
				end
			end
			
			for paramName in pairs(paramMap) do
				local paramId = GameComponentDefs[componentType][paramName]
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
			for paramName in pairs(newParams) do
				currentIndex = currentIndex + 1
				if indicesToFill[currentIndex] then
					GameComponentDefs[componentType][paramName] = indicesToFill[currentIndex]
				else
					maxParamIndex = maxParamIndex + 1
					GameComponentDefs[componentType][paramName] = maxParamIndex
				end
			end
			
			return
		end
		
		-- this component has not been serialized before
		local componentIdListHole
		local componentId
		local paramId = 0

		for i = 1, numUniqueComponents do
			if not ComponentsArray[i] then
				componentIdListHole = i
				break
			end
		end
		
		numUniqueComponents = numUniqueComponents + 1
		GameComponentDefs[componentType] = {}
		
		if not componentIdListHole then
			componentId = numUniqueComponents
		else
			componentId = componentIdListHole
		end

		GameComponentDefs[componentType].ComponentId = componentId

		for paramName  in pairs(paramMap) do
			paramId = paramId + 1
			GameComponentDefs[componentType][paramName] = paramId
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
	end
end

function ComponentsLoader.Init(plugin)
	
	local GameComponentDefModule = Instance.new("ModuleScript")

	if GameComponentDesc then
		for componentType, componentDef in pairs(GameComponentDesc.ComponentDefinitions) do
			GameComponentDefs[componentType] = componentDef
			ComponentsArray[componentDef.ComponentId] = true
			numUniqueComponents = numUniqueComponents + 1
		end
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

