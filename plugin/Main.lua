-- Main.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = script.Parent.Parent
local GameRoot = ReplicatedStorage:FindFirstChild("WorldSmith")
local Systems = script.Parent.PluginSystems
local Components = script.Parent.PluginComponents

local Serial = require(script.Parent.Serial)

function Main(pluginWrapper)
	-- PluginComponents are not persistent
	local numPluginComponents = 0
	local componentDefinitions = {}
	for _, componentModule in ipairs(Components:GetChildren()) do
		local rawComponent = require(componentModule)
		local componentType = rawComponent[1]
		local paramMap = rawComponent[2]
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

	pluginManager.LoadSystem(Systems.GameComponentLoader, pluginWrapper)
	
	local gameManager = GameRoot and require(GameRoot.EntityManager)

	pluginWrapper.GameManager = gameManager
	pluginWrapper.PluginManager = pluginManager
	
	pluginManager.LoadSystem(Systems.ComponentWidget, pluginWrapper)

	pluginWrapper.OnUnloading = function()
		pluginManager.Destroy()
		gameManager.Destroy()
	end

	pluginManager.StartSystems()
end

return Main

