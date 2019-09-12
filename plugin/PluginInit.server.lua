-- PluginInit.lua - stole lots of idea from tiffany352 !!!
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WSAssert = require(script.Parent.Parent.src.WSAssert)

local CLIENT = RunService:IsClient()
local RUNMODE = RunService:IsRunMode()
local SERVER = RunService:IsServer()

local IsCustomSource = true
local OriginalSource = script.Parent.Parent
local WatchedSource = OriginalSource
local CurrentSource = WatchedSource

local Toolbars = {}
local Buttons = {}
local DockWidgets = {}
local WatchedInstances = {}

local PluginWrapper = {}

if not SERVER and CLIENT and RUNMODE then
	error("Not running plugin in RunMode")
end

if not plugin then
	error("Attempted to run plugin in non-plugin context")
end

if IsCustomSource then
	-- this script seems to run before children are loaded...
	local customSource = ServerStorage:WaitForChild("WorldSmith", 2)
	if customSource then
		WatchedSource = customSource
		CurrentSource = WatchedSource
	else
		warn("ServerStorage.WorldSmith does not exist; using original source")
	end
end

function PluginWrapper.GetToolbar(toolbarName)

	if Toolbars[toolbarName] then
		return Toolbars[toolbarName]
	end

	local toolbar = plugin:CreateToolbar(toolbarName)
	Toolbars[toolbarName] = toolbar

	return toolbar
end

function PluginWrapper.GetButton(toolbar, buttonName, buttonTooltip, buttonIcon)

	if Buttons[toolbar] then
		local button = Buttons[toolbar][buttonName]

		if button then
			return button
		end
	else
		Buttons[toolbar] = {}
	end

	local button = toolbar:CreateButton(buttonName, buttonTooltip, buttonIcon or "")
	Buttons[toolbar][buttonName] = button

	return button
end

function PluginWrapper.GetDockWidget(dockWidgetName, ...)

	if DockWidgets[dockWidgetName] then
		return DockWidgets[dockWidgetName]
	end

	local dockWidget = plugin:CreateDockWidgetPluginGui(dockWidgetName, DockWidgetPluginGuiInfo.new(...))
	DockWidgets[dockWidgetName] = dockWidget

	return dockWidget
end

function PluginWrapper.Load()
	local success, result = pcall(require, CurrentSource.plugin.Main)

	WSAssert(success, "plugin failed to load: %s", result)

	local loadedPlugin = result

	success, result = pcall(loadedPlugin, PluginWrapper, CurrentSource, ReplicatedStorage:WaitForChild("WorldSmith", 1))

	WSAssert(success, "plugin failed to run: %s", result)
	WSAssert(PluginWrapper.OnUnloading and typeof(PluginWrapper.OnUnloading) == "function", "expected function PluginWrapper.OnUnloading")
end

function PluginWrapper.Reload()
	PluginWrapper.OnUnloading()
	CurrentSource = WatchedSource:Clone()
	PluginWrapper.Load()
end

function PluginWrapper.Watch(instance)
	if WatchedInstances[instance] then
		return
	end

	if instance == script then
		return
	end

	if instance.Name == "ComponentDefinitions" then
		return
	end

	local ChangedConnection = instance.Changed:Connect(function()
		print("WorldSmith: plugin reloading; " .. instance:GetFullName() .. " changed")
		PluginWrapper.Reload()
	end)

	local ChildAddedConnection = instance.ChildAdded:Connect(function(child)
		PluginWrapper.Watch(child)
	end)

	WatchedInstances[instance] = {ChangedConnection, ChildAddedConnection}

	for _, child in ipairs(instance:GetChildren()) do
		PluginWrapper.Watch(child)
	end
end

PluginWrapper.Load()
PluginWrapper.Watch(WatchedSource)

