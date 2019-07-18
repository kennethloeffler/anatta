-- Main.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = script.Parent.Parent
local GameRoot = ReplicatedStorage:FindFirstChild("WorldSmith")
local Systems = root.plugin.PluginSystems
local Components = root.plugin.PluginComponents

local Serial = require(root.plugin.Serial)

return function(plugin)
	-- PluginComponents are not persistent
	local numPluginComponents = 0
	local componentDefinitions = {}
	for _, componentModule in ipairs(Components:GetChildren())
		local componentType, paramMap  = require(componentModule)
		numPluginComponents = numPluginComponents + 1 
		componentDefinitions[componentType] = {}
		componentDefinitions[componentType].ComponentId = numPluginComponents
		
		local paramId = 0
		for paramName, defaultValue in pairs(paramMap) do
			paramId = paramId + 1
			componentDefinitions[componentType][paramName] = paramId
		end
	end

	local componentDefsModule = Instance.new("ModuleScript")
	componentDefsModule.Name = "ComponentDefinitions"
	componentDefsModule.Source = Serial.Serialize(componentDefinitions)
	componentDefsModule.Parent = root.src.ComponentDesc

	local pluginManager = require(root.src.EntityManager)

	pluginManager.LoadSystem(Systems.GameComponentsLoader, plugin)
	
	local gameManager = GameRoot and require(GameRoot.EntityManager)

	plugin.GameManager = gameManager
	plugin.PluginManager = pluginManager
	
	pluginManager.LoadSystem(Systems.ComponentWidget, plugin)
	pluginManager.LoadSystem(Systems.EntityPersistence, plugin)

	plugin.OnUnloaded = function()
		pluginManager.Destroy()
		gameManager.Destroy()
	end

	pluginManager.StartSystems()
end

