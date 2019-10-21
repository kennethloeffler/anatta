-- GameComponentLoader.lua

-- Copyright 2019 Kenneth Loeffler

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSrc = ReplicatedStorage:WaitForChild("WorldSmith")
local PluginSrc = script.Parent.Parent.Parent.src

local Sandbox = require(script.Parent.Parent.SandboxEnv)
local WSAssert = require(PluginSrc.WSAssert)

local NumUniqueComponents = 0
local ComponentsArray = {}
local SerialComponentDefinitions = {}

local ComponentsLoader = {}

local PluginES
local GameComponentDefsModule
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

	WSAssert(success, "Failed to load component definition module")

	return result
end

local function newComponentDefinition(instance, componentType, paramMap, listTyped, ethereal)
	local componentIdListHole
	local componentIdStr
	local paramId = 0
	local paramList = {}

	if ethereal then
		componentIdStr = HttpService:GenerateGUID(false)
	else
		local componentId

		for i = 1, NumUniqueComponents do
			if not ComponentsArray[i] then
				componentIdListHole = i
				break
			end
		end

		WSAssert(NumUniqueComponents <= 64, "Maximum number of concrete components (64) exceeded")

		if not componentIdListHole then
			componentId = NumUniqueComponents
		else
			componentId = componentIdListHole
		end

		ComponentsArray[componentId] = componentType
		componentIdStr = tostring(componentId)
	end

	for paramName, defaultValue in pairs(paramMap) do
		paramId = paramId + 1

		WSAssert(paramId <= 16, "Maximum number of parameters (16) on \"%s\" exceeded", componentType)

		paramList[paramId] = { ParamName = paramName, DefaultValue = defaultValue }
	end

	PluginES.AddComponent(GameComponentDefsModule, "SerializeComponentDefinition", {
		PluginES.AddComponent(instance, "ComponentDefinition", {
			ComponentType = componentType,
			ComponentId = componentIdStr,
			ListTyped = listTyped,
			ParamList = paramList
		})
	})

	return componentType
end

local function diffComponentDefinition(componentDefinition, componentType, paramMap, listTyped)
	local keptIdx = 1
	local paramList = componentDefinition.ParamList
	local paramName
	local paramValue

	for paramId, paramDefinition in ipairs(paramList) do
		paramName = paramDefinition.ParamName
		paramValue = paramMap[paramName]

		if paramValue then
			paramDefinition.ParamValue = paramValue
			paramMap[paramName] = nil
		else
			paramList[paramId] = false
		end
	end

	for name, value in pairs(paramMap) do
		paramList[#paramList + 1] = { ParamName = name, ParamValue = value }
	end

	for i, paramDefinition in ipairs(paramList) do
		if paramDefinition then
			if i ~= keptIdx then
				paramList[keptIdx] = paramDefinition
				paramList[i] = nil
			end

			keptIdx = keptIdx + 1
		else
			paramList[i] = nil
		end
	end

	WSAssert(#paramList <= 16, "Maximum number of parameters (16) on \"%s\" exceeded", componentType)

	componentDefinition.ComponentType = componentType
	componentDefinition.ListTyped = listTyped

	PluginES.AddComponent(GameComponentDefsModule, "SerializeComponentDefinition", { componentDefinition })
end

local function tryDefineComponent(instance)
	if not instance:IsA("ModuleScript") or (instance:IsA("ModuleScript") and instance.Name == "Component") then
		return
	end

	local pattern = "Component%.Define%("
	local rawComponentDefinition = instance.Source:match(pattern) and tryRequire(instance)

	if not rawComponentDefinition then
		return
	end

	local listTyped = typeof(rawComponentDefinition[1]) == "table"
	local paramMap = rawComponentDefinition[2]
	local ethereal = rawComponentDefinition[3]
	local componentType = listTyped and rawComponentDefinition[1][1] or rawComponentDefinition[1]
	local serialComponentDefinition = SerialComponentDefinitions[componentType]
	local componentDefinition = PluginES.GetComponent(instance, "ComponentDefinition")

	NumUniqueComponents = NumUniqueComponents + (ethereal and 0 or 1)

	if serialComponentDefinition then
		print("found serial")

		local componentIdStr = serialComponentDefinition[1]
		local paramList = {}

		for id, def in pairs(serialComponentDefinition[2]) do
			if id > 1 then
				paramList[id - 1] = def
			end
		end

		PluginES.AddComponent(instance, "ComponentDefinition", {
			ComponentType = componentType,
			ComponentId = componentIdStr,
			ListTyped = listTyped,
			ParamList = paramList
		})

		SerialComponentDefinitions[componentType] = nil

		return componentType
	end

	-- this definition has already been serialized; diff names / params
	if componentDefinition then
		return diffComponentDefinition(componentDefinition, componentType, paramMap, listTyped, ethereal)
	else
		return newComponentDefinition(instance, componentType, paramMap, listTyped, ethereal)
	end
end

local function tryDeleteComponent(instance)
	if not instance:IsA("ModuleScript") or (instance:IsA("ModuleScript") and instance.Name == "Component") then
		return
	end

	local componentDefinition = PluginES.GetComponent(instance, "ComponentDefinition")
	local componentIdStr
	local componentId
	local componentType

	if componentDefinition then
		componentIdStr = componentDefinition.ComponentId
		componentId = tonumber(componentIdStr)
		componentType = componentDefinition.ComponentType

		if componentId then
			ComponentsArray[componentId] = nil
			NumUniqueComponents = NumUniqueComponents - 1
		end

		PluginES.AddComponent(GameComponentDefsModule, "SerializeDeleteComponentDefinition", { componentType })
		PluginES.KillComponent(componentDefinition)

		return componentType
	end
end

function ComponentsLoader.OnLoaded(pluginWrapper)
	GameComponentDefsModule = GameSrc.ComponentDesc:WaitForChild("ComponentDefinitions", 2)
	PluginES = pluginWrapper.PluginES

	if GameComponentDefsModule then
		for componentIdStr, componentDefinition in pairs(require(GameComponentDefsModule)) do
			SerialComponentDefinitions[componentDefinition[1].ComponentType] = { componentIdStr, componentDefinition }
		end
	else
		GameComponentDefsModule = Instance.new("ModuleScript")
		GameComponentDefsModule.Source = "return {}"
		GameComponentDefsModule.Name = "ComponentDefinitions"
		GameComponentDefsModule.Parent = GameSrc.ComponentDesc
	end

	for _, instance in ipairs(ReplicatedStorage:GetDescendants()) do
		tryDefineComponent(instance)
	end

	AddedConnection = ReplicatedStorage.DescendantAdded:Connect(function(instance)
		tryDefineComponent(instance)
	end)

	RemovedConnection = ReplicatedStorage.DescendantRemoving:Connect(function(instance)
		tryDeleteComponent(instance)
	end)
end

function ComponentsLoader.OnUnloaded()
	AddedConnection:Disconnect()
	RemovedConnection:Disconnect()
end

return ComponentsLoader
