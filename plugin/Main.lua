-- Main.lua
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Serial = require(script.Parent.Serial)

function Main(pluginWrapper, root, gameRoot)
	-- PluginComponents are not persistent
	local numPluginComponents = 0
	local componentDefinitions = {}
	local Systems = root.plugin.PluginSystems
	local Components = root.plugin.PluginComponents
	local toolbar = pluginWrapper.GetToolbar("WorldSmith")
	local networkRefButton = pluginWrapper.GetButton(toolbar, "WSReplicatorReference", "Tag the selected enitity as being an EntityReplicator reference")
	local prefabButton = pluginWrapper.GetButton(toolbar, "WSPrefabRootInstance", "Tag the selected instance as being an EntityReplicator prefab root instance")

	for _, componentModule in ipairs(Components:GetChildren()) do
		local rawComponent = require(componentModule)
		local componentType = rawComponent[1]
		local paramMap = rawComponent[2]
		local paramId = 1

		numPluginComponents = numPluginComponents + 1
		componentDefinitions[componentType] = {}
		componentDefinitions[componentType][1] = numPluginComponents

		for paramName, defaultValue in pairs(paramMap) do
			paramId = paramId + 1
			componentDefinitions[componentType][paramId] = { ["paramName"] = paramName, ["defaultValue"] = defaultValue }
		end
	end

	local componentDefsModule = root.src.ComponentDesc:WaitForChild("ComponentDefinitions", 2) or Instance.new("ModuleScript")
	componentDefsModule.Name = "ComponentDefinitions"
	componentDefsModule.Source = Serial.Serialize(componentDefinitions)
	componentDefsModule.Parent = root.src.ComponentDesc

	local pluginManager = require(root.src.EntityManager)

	pluginManager.LoadSystem(Systems.GameComponentLoader, pluginWrapper)

	local gameManager = gameRoot and require(gameRoot.EntityManager)

	pluginWrapper.GameManager = gameManager
	pluginWrapper.PluginManager = pluginManager

	pluginManager.LoadSystem(Systems.ComponentWidget, pluginWrapper)
	pluginManager.LoadSystem(Systems.AddComponentWidget, pluginWrapper)
	pluginManager.LoadSystem(Systems.EntityPersistence, pluginWrapper)
	pluginManager.LoadSystem(Systems.ComponentWidgetList, pluginWrapper)

	pluginWrapper.OnUnloading = function()
		local dockWidget = pluginWrapper.GetDockWidget("Components")

		if dockWidget then
			dockWidget:ClearAllChildren()
		end

		pluginManager.Destroy()
		gameManager.Destroy()
	end

	coroutine.wrap(pluginManager.StartSystems)()
end

return Main

