local CollectionService = game:GetService("CollectionService")

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

local function splitCommaDelineatedString(str)
	local list = {}

	for s in string.gmatch(str, "([^,]+)") do
		list[#list + 1] = tonumber(s)
	end

	return unpack(list)
end


function GameEntityBridge.OnLoaded(pluginWrapper)
	PluginES = pluginWrapper.PluginManager
	GameES = pluginWrapper.GameManager
	ComponentDesc = GameES.GetComponentDesc()

	PluginES.ComponentAdded("SerializeParam", function(serializeParam)
		local paramField = serializeParam.ParamField
		local entity = serializeParam.Entity

		if not CollectionService:HasTag(entity, "__WSEntity") then
			return
		end

		local module, entityStruct = getEntityStruct(entity)
		local componentId = paramField.ComponentId

		if not entityStruct[ComponentDesc.GetComponentTypeFromId(componentId)] then
			return
		end

		local paramId = paramField.ParamId

		entityStruct[paramId] = paramField.ParamValue
		module.Source = Serial.Serialize(entityStruct)

		GameES.GetComponent(entity, paramField.ComponentType)[ComponentDesc.GetParamNameFromId(componentId, paramId)] = paramField.ParamValue
	end)

	PluginES.ComponentAdded("SerializeNewComponent", function(serializeNewComponent)
		local entity = serializeNewComponent.Entity
		local componentType = serializeNewComponent.ComponentType
		local module, entityStruct = getEntityStruct(entity)
		local componentStruct = GameES.AddComponent(entity, componentType)

		entityStruct[componentType] = componentStruct
		module.Source = Serial.Serialize(entityStruct)
	end)
end

return GameEntityBridge

