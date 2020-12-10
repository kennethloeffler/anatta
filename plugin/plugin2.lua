-- Adapted from
-- https://github.com/tiffany352/Roblox-Tag-Editor/blob/bd48fb7ceea6bcd1cd9c515891ae4eb4eb9d1a71/src/Loader.server.lua
-- thanks tiffany! :)

-- Sanity check.
assert(plugin, "Plugin2 must be executed as a plugin!")

local ServerStorage = game:GetService("ServerStorage")
local Studio = settings().Studio

-- RenderStepped errors out in Start Server, so we consider it a hostile environment even
-- though it has a 3D view that we could potentially be using.
if not game:GetService("RunService"):IsClient() then
	return
end

-- Change to true to enable hot reloading support. Opening a place containing the code
-- synced via Rojo will cause the plugin to be reloaded in edit mode. (No need for play
-- solo or the hotswap plugin.)
local useDevSource = true
local devSource = ServerStorage:WaitForChild("AnattaStudioPlugin", 3)

-- The source that's shipped integrated into the plugin.
local builtinSource = script.Parent

-- `source` is where we should watch for changes. `currentRoot` is the clone we make of
-- source to avoid require() returning stale values.
local source = builtinSource
local currentRoot = source

if useDevSource then
	if devSource ~= nil then
		source = devSource
		currentRoot = source
	else
		warn("Plugin development source is not present, running using built-in source.")
	end
end

local RbxPlugin
local Plugin2 = {}
Plugin2.__index = Plugin2

function Plugin2.new(rbxPlugin)
	RbxPlugin = rbxPlugin

	local plugin2 = setmetatable({
		_toolbars = {},
		_buttons = {},
		_pluginGuis = {},
		_menus = {},
		_actions = {},
		_watching = {},
		_connections = {},
		_beforeUnload = nil,
		isDev = useDevSource and devSource ~= nil,
	}, Plugin2)

	RbxPlugin.Unloading:Connect(function()
		Plugin2:unload()
	end)

	Plugin2.load()
	Plugin2:_watch(source)

	return plugin2
end

function Plugin2:getTheme()
	return self._theme or Studio.Theme
end

function Plugin2:setTheme(enum)
	if enum then
		self._theme = enum
	else
		self._theme = Studio.Theme
	end
end

function Plugin2:themeChanged(callback)
	table.insert(self._connections, Studio.ThemeChanged:Connect(callback))
end

function Plugin2:toolbar(name)
	if self._toolbars[name] then
		return self._toolbars[name]
	end

	local toolbar = RbxPlugin:CreateToolbar(name)

	self._toolbars[name] = toolbar

	return toolbar
end

function Plugin2:button(params)
	local icon = params.icon
	local active = params.active
	local tooltip = params.tooltip
	local toolbar = params.toolbar
	local name = params.name

	local existingButtons = self._buttons[toolbar]

	if existingButtons then
		local existingButton = existingButtons[name]

		if existingButton then
			return existingButton
		end
	else
		existingButtons = {}
		self._buttons[toolbar] = existingButtons
	end

	local button = toolbar:CreateButton(name, tooltip, icon)

	existingButtons[name] = button
	button:SetActive(active)

	return button
end

function Plugin2:dockWidget(name, title, ...)
	if self._pluginGuis[name] then
		return self._pluginGuis[name]
	end

	local gui = RbxPlugin:CreateDockWidgetRbxPluginGui(name, DockWidgetPluginGuiInfo.new(...))

	self._RbxPluginGuis[name] = gui
	gui.Name = name
	gui.Title = title

	return gui
end

function Plugin2:action(params)
     local actionId = params.actionId
     local name = params.name
     local tip = params.tip
     local icon = params.icon
     local allowBinding = params.allowBinding
     local func = params.func

	local existingAction = self._actions[actionId]

	if existingAction then
		-- assume the plugin is reloading and disconnect the currently connected function
		existingAction.connection:Disconnect()
		existingAction.connection = existingAction.action.Triggered:Connect(func)

		return existingAction.action
     end

     local action = RbxPlugin:CreateRbxPluginAction(actionId, name, tip, icon, allowBinding)

     self._actions[actionId] = {
		connection = action.Triggered:Connect(func),
		action = action
	}

     return action
end

function Plugin2:menu(id, title, icon)
	if self._menus[id] then
		return self._menus[id]
	end

	local menu = RbxPlugin:CreatePluginMenu(id, title, icon)

	self._menus[id] = {
		ShowAsync = function()
			menu:ShowAsync()
		end,
		AddNewAction = function(_, params)
			local actionId = params.actionId
			local text = params.text
			local actionIcon = params.icon
			local func = params.func

			local existingAction = self._actions[actionId]

			if existingAction then
				existingAction.connection:Disconnect()
				existingAction.connection = existingAction.action.Triggered:Connect(func)

				return
			end

			local action = menu:AddNewAction(actionId, text, actionIcon)

			self._actions[actionId] = {
				connection = action.Triggered:Connect(func),
				action = action
			}
		end
	}

	return self._menus[id]
end

--[[
	Sets the method to call the next time the system tries to reload
]]
function Plugin2:beforeUnload(callback)
	self._beforeUnload = callback
end

function Plugin2.load()
	-- clone if we're using dev source b/c the first require will be stale after writing
	-- out to file for the first time
	local main = useDevSource and currentRoot:Clone() or currentRoot
	local ok, result = pcall(require, main)

	if not ok then
		warn("RbxPlugin failed to load: " .. result)
		return
	end

	local Plugin = result

	ok, result = pcall(Plugin, Plugin2)

	if not ok then
		warn("Plugin failed to run: " .. result)
		return
	end
end

function Plugin2:unload()
	for i, connection in ipairs(self._connections) do
		connection:Disconnect()
		self._connections[i] = nil
	end

	if self._beforeUnload then
		local saveState = self._beforeUnload()
		self._beforeUnload = nil

		return saveState
	end
end

function Plugin2:_reload()
	local saveState = self:unload()
	currentRoot = source:Clone()

	self.load(saveState)
end

function Plugin2:_watch(instance)
	if self._watching[instance] then
		return
	end

	-- Don't watch ourselves!
	if instance == script then
		return
	end

	local changedConnection

	if instance:IsA("ModuleScript") then
		changedConnection = instance.Changed:Connect(function()
			print("Reloading due to", instance:GetFullName())
			self:_reload()
		end)
	end

	local childAddedConnection = instance.ChildAdded:Connect(function()
		self:_watch(instance)
	end)


	local watched = {
		childAddedConnection = childAddedConnection,
		changedConnection = changedConnection
	}

	self._watching[instance] = watched

	for _, child in ipairs(instance:GetChildren()) do
		self:_watch(child)
	end
end

return Plugin2
