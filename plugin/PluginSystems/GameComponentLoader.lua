local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSrc = ReplicatedStorage:WaitForChild("WorldSmith")
local PluginSrc = script.Parent.Parent.Parent.src

local Constants = require(PluginSrc.Constants)
local Sandbox = require(script.Parent.Parent.SandboxEnv)
local Serial = require(script.Parent.Parent.Serial)
local WSAssert = require(PluginSrc.WSAssert)

local NumUniqueComponents = 0
local ComponentsArray = {}
local GameComponentDefs = {}

local ComponentsLoader = {}

local AddedConnection
local RemovedConnection

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
	local rawComponentDef = instance.Source:match(pattern) and tryRequire(instance)

	if rawComponentDef then
		local componentType = rawComponentDef[1]
		local paramMap = rawComponentDef[2]
		local componentDescription = GameComponentDefs[componentType]

		-- this componentType has already been serialized; diff params
		if componentDescription then
			local numParams
			local paramId

			warn(("WorldSmith: found existing component %s"):format(componentType))

			for id, paramDescription in ipairs(componentDescription) do
				if id > 1 then
					if not paramMap[paramDescription.paramName] then
						numParams = #componentDescription
						componentDescription[id] = componentDescription[numParams]
						componentDescription[numParams] = nil
						warn(("WorldSmith: removed parameter %s; moved parameter %s to paramId %s"):format(paramDescription.paramName, componentDescription[id].paramName, tostring(id)))
					else
						if not paramDescription.defaultValue == paramMap[paramDescription.paramName] then
							paramDescription.defaultValue = paramMap[paramDescription.paramName]
							warn(("WorldSmith: set default value of parameter %s to %s"):format(paramDescription.paramName, tostring(paramMap[paramDescription.paramName])))
						end

						paramMap[paramDescription.paramName] = nil
					end
				end
			end

			for paramName, defaultValue in pairs(paramMap) do
				paramId = #componentDescription

				WSAssert(paramId <= 17, "Maximum number of parameters (16) exceeded")

				componentDescription[paramId + 1] = { ["paramName"] = paramName, ["defaultValue"] = defaultValue }
				warn(("WorldSmith: added parameter %s"):format(paramName))
			end

			return true
		end

		-- this componentType has not been serialized before
		local componentIdListHole
		local componentId
		local paramId = 1

		for i = 1, NumUniqueComponents do
			if not ComponentsArray[i] then
				componentIdListHole = i
				break
			end
		end

		NumUniqueComponents = NumUniqueComponents + 1

		WSAssert(NumUniqueComponents <= 64, "Maximum number of components (64) exceeded")

		GameComponentDefs[componentType] = {}
		componentDescription = GameComponentDefs[componentType]

		if not componentIdListHole then
			componentId = NumUniqueComponents
		else
			componentId = componentIdListHole
		end

		warn(("WorldSmith: created component description for new component \"%s\"  with componentId %s"):format(componentType, tostring(componentId)))

		componentDescription[1] = componentId
		ComponentsArray[componentId] = componentType

		for paramName, defaultValue in pairs(paramMap) do
			paramId = paramId + 1

			WSAssert(paramId <= 17, "Maximum number of parameters (16) exceeded")

			componentDescription[paramId] = { ["paramName"] = paramName, ["defaultValue"] = defaultValue }
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
	local GameComponentDefModule = GameSrc.ComponentDesc:WaitForChild("ComponentDefinitions", 2)

	if GameComponentDefModule then
		for componentType, componentDef in pairs(require(GameComponentDefModule)) do
			WSAssert(NumUniqueComponents <= 64, "Maximum number of components (64) exceeded")

			GameComponentDefs[componentType] = componentDef
			ComponentsArray[componentDef[1]] = componentType
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

	AddedConnection = ReplicatedStorage.DescendantAdded:Connect(function(inst)
		if tryCollectComponent(inst) then
			GameComponentDefModule.Source = Serial.Serialize(GameComponentDefs)
		end
	end)

	RemovedConnection = ReplicatedStorage.DescendantRemoving:Connect(function(inst)
		if tryRemoveComponent(inst) then
			GameComponentDefModule.Source = Serial.Serialize(GameComponentDefs)
		end
	end)
end

function ComponentsLoader.OnUnloaded()
	AddedConnection:Disconnect()
	RemovedConnection:Disconnect()
end

return ComponentsLoader

