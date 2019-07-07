-- PluginInit.lua
local RunService = game:GetService("RunService")

local WSAssert = require(script.Parent.Parent.src.WSAssert)

local CLIENT = RunService:IsClient()
local RUNMODE = RunService:IsRunmode()
local SERVER = RunService:IsServer()

local PluginSource = script.Parent.Parent
local WatchedSource = PluginSource
local CurrentSource = WatchedSource

local Toolbars = {}
local Buttons = {}
local DockWidgets = {}
local WatchedInstances = {}
local UnloadedCallback

local PluginWrapper = {}

if not SERVER and CLIENT and RUNMODE then
	-- don't load plugin in runmode client
	return
end

WSAssert(plugin ~= nil, "attempt to run plugin in non-plugin context")

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

function PluginWrapper.Load(cachedState)
end

function PluginWrapper.Unload()
end

function PluginWrapper.Reload()
end

function PluginWrapper.Watch(instance)
end

PluginWrapper.Load()
PluginWrapper.Watch(

