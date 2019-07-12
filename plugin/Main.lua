-- Main.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = script.Parent.Parent
local PluginManager = require(root.src.EntityManager)
local GameRoot = ReplicatedStorage:FindFirstChild("WorldSmith")
local GameManager = GameRoot and GameRoot:FindFirstChild("EntityManager")
local Systems = root.plugin.PluginSystems

-- oh yeah bb
if GameManager then
	GameManager = require(GameManager)
end

return function(plugin)

	plugin.GameManager = GameManager

	PluginManager.LoadSystem(Systems.GameComponentLoader, plugin)
	PluginManager.LoadSystem(Systems.ComponentPropWidget, plugin)
	PluginManager.LoadSystem(Systems.EntityPersistence, plugin)

	plugin.OnUnloaded = function()
		PluginManager.Destroy()
		GameManager.Destroy()
	end

	PluginManager.StartSystems()
end

