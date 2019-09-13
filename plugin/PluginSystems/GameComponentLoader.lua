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

local function tryRequire(moduleScript)
	local env = Sandbox.new(moduleScript)

	local success, result = xpcall(function()
		return env.require(moduleScript)
	end,

	function(err)
		return err
	end)

	WSAssert(success, "Tried to load component definition module: " .. moduleScript:GetFullName())

	return result
end

local function tryCollectComponent(instance)
	if not instance:IsA("ModuleScript") or instance.Name == "Component" then
		return
	end

	local pattern = "Component%.Define%("
	local rawComponentDef = tryRequire(instance)

	if instance.Source:match(pattern) and rawComponentDef then
		local componentType = rawComponentDef[1]
		local paramMap = rawComponentDef[2]
		local componentDescription = GameComponentDefs[componentType]

		-- this componentType has already been serialized; diff params
		if componentDescription then
			local numParams
			local paramId

			warn(("WorldSmith: found existing component %s"):format(componentType))

			for paramId, paramDescription in ipairs(componentDescription) do
				if not paramMap[paramName] then
					numParams = #componentDescription
					componentDescription[paramId] = componentDescription[numParams]
					componentDescription[numParams] = nil
					warn(("WorldSmith: removed parameter %s; moved parameter %s to paramId %s"):format(paramDescription.paramName, componentDescription[paramId].paramName, tostring(paramId)))
				else
					if not paramDescription.defaultValue == paramMap[paramName] then
						paramDescription.defaultValue = paramMap[paramName]
						warn(("WorldSmith: set default value of parameter %s to %s"):format(paramDescription.paramName, tostring(paramMap[paramName])))
					end

					paramMap[paramName] = nil
				end
			end

			for paramName, defaultValue in pairs(paramMap) do
				paramId = #componentDescription + 1

				WSAssert(paramId <= 16, "Maximum number of parameters (16) exceeded")

				componentDescription[paramId] = { ["paramName"] = paramName, ["defaultValue"] = defaultValue }
				warn(("WorldSmith: added parameter %s"):format(paramName))
			end

			return true
		end

		-- this componentType has not been serialized before
		local componentIdListHole
		local componentId
		local paramId = 0

		for i = 1, NumUniqueComponents do
			if not ComponentsArray[i] then
				componentIdListHole = i
				break
			end
		end

		NumUniqueComponents = NumUniqueComponents + 1

		WSAssert(NumUniqueComponents <= 64, "Maximum number of components (64) exceeded")

		GameComponentDefs[componentType] = {}
		component = GameComponentDefs[componentType]

		if not componentIdListHole then
			componentId = NumUniqueComponents
		else
			componentId = componentIdListHole
		end

		warn(("WorldSmith: created component description for new component \"%s\"  with componentId %s"):format(componentType, tostring(componentId)))

		component.ComponentId = componentId
		ComponentsArray[componentId] = componentType

		for paramName, defaultValue in pairs(paramMap) do
			paramId = paramId + 1

			WSAssert(paramId <= 16, "Maximum number of parameters (16) exceeded")

			componentDescription[paramId] = { ["paramName"] = paramName, ["paramName"] = defaultValue }
		end

		return true
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

		return true
	end
end

function ComponentsLoader.OnLoaded()
	local GameComponentDefModule = GameSrc.ComponentDesc:WaitForChild("ComponentDefinitions", 1)

	if GameComponentDefModule then
		for componentType, componentDef in pairs(require(GameComponentDefModule)) do
			WSAssert(NumUniqueComponents <= 64, "Maximum number of components (64) exceeded")

			GameComponentDefs[componentType] = componentDef
			ComponentsArray[componentDef.ComponentId] = componentType
			NumUniqueComponents = NumUniqueComponents + 1
		end
	else
		GameComponentDefModule = Instance.new("ModuleScript")
	end

	for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
		tryCollectComponent(inst)
	end

	GameComponentDefModule.Source = Serial.Serialize(GameComponentDefs)
	GameComponentDefModule.Name = "ComponentDefinitions"
	GameComponentDefModule.Parent = GameSrc.ComponentDesc

	ReplicatedStorage.DescendantAdded:Connect(function(inst)
		if tryCollectComponent(inst) then
			GameComponentDefModule.Source = Serial.Serialize(GameComponentDefs)
		end
	end)

	ReplicatedStorage.DescendantRemoving:Connect(function(inst)
		if tryRemoveComponent(inst) then
			GameComponentDefModule.Source = Serial.Serialize(GameComponentDefs)
		end
	end)
end

return ComponentsLoader

