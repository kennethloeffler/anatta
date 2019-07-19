local Serial = require(script.Parent.Parent.Serial)

local EntityPersistence = {}

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

function EntityPersistence.Init(pluginWrapper)
	local PluginManager = pluginWrapper.PluginManager
	local GameManager = pluginWrapper.GameManager

	PluginManager.ComponentAdded("DoSerializeEntity"):Connect(scrollingFrame)
		local doSerializeEntity = PluginManager.GetComponent(scrollingFrame, "DoSerializeEntity")
		for _, inst in ipairs(doSerializeEntity.InstanceList) do

			GameManager.AddComponent(inst, doSerializeEntity.ComponentType)
			
			local struct, module = getEntityStruct(inst)
			local componentType = doSerializeEntity.ComponentType
			local componentToSerialize = GameManager.GetComponent(inst, componentType)

			struct[componentType] = {}

			for index, value in pairs(componentToSerialize) do
				struct[componentType][#struct[componentType] + 1] = {paramId = index, paramValue = value}
			end

			module.Source = Serial.Serialize(struct)
		end
	end)
end

return EntityPersistence

