-- GameEntityBridge.lua
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
		local gameComponent
		local module
		local entityStruct

		for _, instance in ipairs(serializeParam.EntityList) do
			gameComponent = GameES.GetComponent(instance, componentType)

			if gameComponent then
				module, entityStruct = getEntityStruct(instance)
				entityStruct[componentIdStr][paramId + 1] = serializeParam.Value

				gameComponent[paramName] = serializeParam.Value

				module.Source = Serial.Serialize(entityStruct)
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

		for _, instance in ipairs(serializeAddComponent.EntityList) do
			gameComponent = GameES.GetComponent(instance, componentType)

			if not gameComponent then
				gameComponent = GameES.AddComponent(instance, componentType)

				module, entityStruct = getEntityStruct(instance)
				serialComponentStruct = {}
				entityStruct[componentIdStr] = serialComponentStruct

				for i, v in ipairs(gameComponent) do
					serialComponentStruct[i] = v
				end

				module.Source = Serial.Serialize(entityStruct)
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

		for _, instance in ipairs(serializeKillComponent.EntityList) do
			gameComponent = GameES.GetComponent(instance, componentType)

			if gameComponent then
				module, entityStruct = getEntityStruct(instance)
				entityStruct[componentIdStr] = nil

				GameES.KillComponent(gameComponent)

				if not next(entityStruct) then
					module:Destroy()
				else
					module.Source = Serial.Serialize(entityStruct)
				end
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
		local gameComponentDefinitions = Serial.Deserialize(module.Source)
		local serialComponentDefinition = gameComponentDefinitions[componentIdStr]
		local entityStruct, entityModule

		if not serialComponentDefinition then
			serialComponentDefinition = {{ ComponentType = componentType, ListTyped = listTyped }}
			gameComponentDefinitions[componentIdStr] = serialComponentDefinition
		else
			serialComponentDefinition[1].ListTyped = listTyped
			serialComponentDefinition[1].ComponentType = componentType

			for paramId, paramDefinition in ipairs(componentDefinition.ParamList) do
				if typeof(paramDefinition.ParamValue) ~= typeof(serialComponentDefinition[paramId + 1].ParamValue) then
					changedTypes[paramId] = paramDefinition.ParamValue
				end
			end

			for _, component in ipairs(GameES.GetAllComponentsOfType(ComponentDesc.GetComponentTypeFromId(componentId))) do
				entityStruct, entityModule = getEntityStruct(component.Instance)

				for paramId, paramValue in ipairs(changedTypes) do
					entityStruct[componentIdStr][paramId] = paramValue
					component[paramId] = paramValue
				end

				entityModule.Source = Serial.Serialize(entityStruct)
			end
		end

		module.Source = Serial.Serialize(gameComponentDefinitions)

		PluginES.KillComponent(serializeComponentDefinition)
	end)

	PluginES.ComponentAdded("SerializeDeleteComponentDefinition", function(serializeDeleteComponentDefinition)
		local componentType = serializeDeleteComponentDefinition.ComponentType
		local componentId = ComponentDesc.GetComponentIdFromType(componentType)
		local componentIdStr = ComponentDesc.GetEtherealIdFromComponentId(componentId) or tostring(componentId)
		local componentDefinitions
		local module
		local entityStruct

		for _, gameComponent in ipairs(GameES.GetAllComponentsOfType(componentType)) do
			module, entityStruct = getEntityStruct(gameComponent.Instance)
			entityStruct[componentIdStr] = nil

			GameES.KillComponent(gameComponent)

			if not next(entityStruct) then
				module:Destroy()
			else
				module.Source = Serial.Serialize(entityStruct)
			end
		end

		module = serializeDeleteComponentDefinition.Instance
		componentDefinitions = Serial.Deserialize(module.Source)
		componentDefinitions[componentIdStr] = nil
		module.Source = Serial.Serialize(componentDefinitions)

		PluginES.KillComponent(serializeDeleteComponentDefinition)
	end)
end

return GameEntityBridge
