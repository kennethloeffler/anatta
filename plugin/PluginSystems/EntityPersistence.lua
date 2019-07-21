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

	PluginManager.ComponentAdded("DoSerializeEntity"):Connect(function(scrollingFrame)
		local doSerializeEntity = PluginManager.GetComponent(scrollingFrame, "DoSerializeEntity")
		for _, inst in ipairs(doSerializeEntity.InstanceList) do
			local struct, module = getEntityStruct(inst)
			local componentType = doSerializeEntity.ComponentType
			if not struct[componentType] or next(doSerializeEntity.Params) then
				local componentToSerialize = GameManager.AddComponent(inst, doSerializeEntity.ComponentType, doSerializeEntity.Params)
				struct[componentType] = {}

				for index, value in pairs(componentToSerialize) do
					if typeof(index) == "number" then
						struct[componentType][#struct[componentType] + 1] = {paramId = index, paramValue = value}
					end
				end
			else
				struct[componentType] = nil
				GameManager.KillComponent(inst, componentType)
			end

			module.Source = Serial.Serialize(struct)
		end
		PluginManager.KillComponent(scrollingFrame, "DoSerializeEntity")
	end)
end

return EntityPersistence

