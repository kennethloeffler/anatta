-- GameEntityBridge.lua

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

local Serial = require(script.Parent.Parent.Serial)

local PluginES
local GameES
local ComponentDesc

local GameEntityBridge = {}

local function getEntityStruct(inst)
	local module = inst:FindFirstChild("__WSEntity")
	local struct

	if module then
		struct = Serial.Deserialize(module.Source)
	else
		module = Instance.new("ModuleScript")
		module.Name = "__WSEntity"
		module.Parent = inst
		struct = {}
	end

	return struct, module
end

function GameEntityBridge.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginES
	GameES = pluginWrapper.GameES
	ComponentDesc = GameES.GetComponentDesc()

	PluginES.ComponentAdded("SerializeParam", function(serializeParam)
		local componentType = serializeParam.ComponentType
		local paramName = serializeParam.ParamName
		local componentId = ComponentDesc.GetComponentIdFromType(componentType)
		local componentIdStr = ComponentDesc.GetEtherealIdFromComponentId(componentId) or tostring(componentId)
		local paramId = ComponentDesc.GetParamIdFromName(componentId, paramName)
		local paramValue = serializeParam.Value
		local components
		local gameComponent
		local module
		local entityStruct

		for _, instance in ipairs(serializeParam.EntityList) do
			gameComponent = GameES.GetComponent(instance, componentType)

			if gameComponent then
				components = instance:GetAttribute("__WSEntity")

				components[componentIdStr][paramId] = paramValue
				gameComponent[paramName] = paramValue
				instance:SetAttribute("__WSEntity", components)
			end
		end

		PluginES.KillComponent(serializeParam)
	end)

	PluginES.ComponentAdded("SerializeAddComponent", function(serializeAddComponent)
		local componentType = serializeAddComponent.ComponentType
		local componentId = ComponentDesc.GetComponentIdFromType(componentType)
		local componentIdStr = ComponentDesc.GetEtherealIdFromComponentId(componentId) or tostring(componentId)
		local gameComponent
		local module
		local entityStruct
		local serialComponentStruct
		local components

		for _, instance in ipairs(serializeAddComponent.EntityList) do
			gameComponent = GameES.GetComponent(instance, componentType)

			if not gameComponent then
				components = instance:GetAttribute("__WSEntity") or {}
				gameComponent = GameES.AddComponent(instance, componentType)

				components[componentIdStr] = {}

				for paramId, paramValue in ipairs(gameComponent) do
					components[componentIdStr][paramId] = paramValue
				end

				instance:SetAttribute("__WSEntity", components)
			end
		end

		PluginES.KillComponent(serializeAddComponent)
	end)

	PluginES.ComponentAdded("SerializeKillComponent", function(serializeKillComponent)
		local componentType = serializeKillComponent.ComponentType
		local componentId = ComponentDesc.GetComponentIdFromType(componentType)
		local componentIdStr = ComponentDesc.GetEtherealIdFromComponentId(componentId) or tostring(componentId)
		local gameComponent
		local module
		local entityStruct
		local components

		for _, instance in ipairs(serializeKillComponent.EntityList) do
			gameComponent = GameES.GetComponent(instance, componentType)
			

			if gameComponent then
				components = instance:GetAttribute("__WSEntity")
				
				components[componentType] = nil
				instance:SetAttribute("__WSEntity", next(components) ~= nil and components or nil)
				
				GameES.KillComponent(gameComponent)
			end
		end

		PluginES.KillComponent(serializeKillComponent)
	end)

	PluginES.ComponentAdded("SerializeComponentDefinition", function(serializeComponentDefinition)
		local module = serializeComponentDefinition.Instance
		local changedTypes = {}
		local componentDefinition = serializeComponentDefinition.ComponentDefinition
		local componentType = componentDefinition.ComponentType
		local componentIdStr = componentDefinition.ComponentId
		local componentId = tonumber(componentIdStr) or ComponentDesc.GetComponentIdFromEtherealId(componentIdStr)
		local listTyped = componentDefinition.ListTyped
		local gameComponentDefinitions = module:GetAttribute("__WSComponentDefinitions") or {}
		local serialComponentDefinition = gameComponentDefinitions[componentIdStr]
		local components

		if not serialComponentDefinition then
			serialComponentDefinition = { { ComponentType = componentType, ListTyped = listTyped } }
			gameComponentDefinitions[componentIdStr] = serialComponentDefinition
		else
			serialComponentDefinition[1].ListTyped = listTyped
			serialComponentDefinition[1].ComponentType = componentType

			for paramId, paramDefinition in ipairs(componentDefinition.ParamList) do
				if typeof(paramDefinition.ParamValue) ~= (serialComponentDefinition[paramId + 1].ParamValue == "__InstanceReferent" and "Instance"
				or typeof(serialComponentDefinition[paramId + 1].ParamValue)) then
					changedTypes[paramId] = paramDefinition.ParamValue
					componentDefinition.ParamList[paramId] = nil
				end
			end

			for _, gameComponent in ipairs(GameES.GetAllComponentsOfType(ComponentDesc.GetComponentTypeFromId(componentId))) do
				components = gameComponent.Instance:GetAttribute("__WSEntity")

				for paramId, paramValue in pairs(changedTypes) do
					components[componentIdStr][paramId] = typeof(paramValue) == "Instance" and "__InstanceReferent" or paramValue
					component[paramId] = paramValue
				end

				gameComponent.Instance:SetAttribute("__WSEntity", components)
			end
		end

		for paramId, paramDefinition in pairs(componentDefinition.ParamList) do
			if typeof(paramDefinition.DefaultValue) == "Instance" then
				paramDefinition.DefaultValue = "__InstanceReferent"
			end

			serialComponentDefinition[paramId + 1] = paramDefinition
		end

		module:SetAttribute("__WSComponentDefinitions", gameComponentDefinitions)

		PluginES.KillComponent(serializeComponentDefinition)
	end)

	PluginES.ComponentAdded("SerializeDeleteComponentDefinition", function(serializeDeleteComponentDefinition)
		local componentType = serializeDeleteComponentDefinition.ComponentType
		local componentId = ComponentDesc.GetComponentIdFromType(componentType)
		local componentIdStr = ComponentDesc.GetEtherealIdFromComponentId(componentId) or tostring(componentId)
		local componentDefinitions = serializeDeleteComponentDefinition.Instance:GetAttribute("__WSComponentDefinitions")
		local module
		local entityStruct
		local components

		for _, gameComponent in ipairs(GameES.GetAllComponentsOfType(componentType)) do
			GameES.KillComponent(gameComponent)

			gameComponent.Instance:SetAttribute("__WSEntity", nil)
		end

		componentDefinitions[componentIdStr] = nil

		PluginES.KillComponent(serializeDeleteComponentDefinition)
	end)
end

return GameEntityBridge
