-- PluginInit.lua - stole lots of idea from tiffany352 !!!
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local WSAssert = require(script.Parent.Parent.src.WSAssert)

local CLIENT = RunService:IsClient()
local RUNMODE = RunService:IsRunmode()
local SERVER = RunService:IsServer()

local IsCustomSource = false
local OriginalSource = script.Parent.Parent
local WatchedSource = OriginalSource
local CurrentSource = WatchedSource

local Toolbars = {}
local Buttons = {}
local DockWidgets = {}
local WatchedInstances = {}

local PluginWrapper = {}

PluginWrapper.OnUnloading = nil

if not SERVER and CLIENT and RUNMODE then
	-- don't load plugin in runmode client
	return
end

WSAssert(plugin ~= nil, "attempt to run plugin in non-plugin context")

if IsCustomSource then
	local customSource = ServerStorage:FindFirstChild("WorldSmith")
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

function PluginWrapper.GetButton(toolbarName, buttonName, buttonTooltip, buttonIcon)
   
	if Buttons[toolbarName] then
		local button = buttons[buttonName]
		if button then
			return button
		end
	else
		Buttons[toolbarName] = {}
	end

	local button = plugin:CreateButton(buttonName, buttonTooltip, buttonIcon)
	Buttons[toolbarName][buttonName] = button
	
	return button
end

function PluginWrapper.GetDockWidget(dockWidgetName, ...)

	if DockWidgets[dockWidgetName] then
		return DockWidgets[dockWidgetName]
	end

	local dockWidget = plugin:CreateDockWidgetPluginGui(dockWidgetName, ...)
	DockWidgets[dockWidgetName] = dockWidget

	return dockWidget
end

function PluginWrapper.Load()
	local success, result = pcall(require, CurrentSource.plugin.Main)

	WSAssert(success, "plugin failed to load: %s", result)

	local loadedPlugin = result

	success, result = pcall(loadedPlugin, PluginWrapper)

	WSAssert(success, "plugin failed to run: %s", result)
	WSAssert(PluginWrapper.OnUnloaded, "PluginWrapper.OnUnloading is nil")
end

function PluginWrapper.Reload()
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

plugin.Unloading:Connect(PluginWrapper.OnUnloading)
