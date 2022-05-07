local Selection = game:GetService("Selection")

local Modules = script.Parent.Parent
local Roact = require(Modules.Roact)
local Rodux = require(Modules.Rodux)
local RoactRodux = require(Modules.RoactRodux)

local App = require(script.Parent.Components.App)
local Reducer = require(script.Parent.Reducer)
local ComponentManager = require(script.Parent.ComponentManager)
local Actions = require(script.Parent.Actions)
local Config = require(script.Parent.Config)
local PluginGlobals = require(script.Parent.PluginGlobals)

local function getSuffix(plugin)
	if plugin.isDev then
		return " [DEV]", "Dev"
	elseif Config.betaRelease then
		return " [BETA]", "Beta"
	end

	return "", ""
end

return function(plugin, savedState)
	local displaySuffix, nameSuffix = getSuffix(plugin)
	local componentClipboard = {}

	local toolbar = plugin:toolbar("Anatta" .. displaySuffix)

	local toggleButton = plugin:button(
		toolbar,
		"Component Editor",
		"Manipulate components",
		"http://www.roblox.com/asset/?id=1367281857"
	)

	local worldViewButton = plugin:button(
		toolbar,
		"World View",
		"Visualize entities and their components in the 3D view",
		"http://www.roblox.com/asset/?id=1367285594"
	)

	local copyButton = plugin:button(toolbar, "Copy Components", "Copy components from a selected instance.", "")

	local pasteButton = plugin:button(
		toolbar,
		"Paste Components",
		"Paste currently copied components onto selected instances.",
		""
	)

	local store = Rodux.Store.new(Reducer, savedState)

	local function copyComponents()
		local selected = Selection:Get()

		if #selected > 1 then
			error("Cannot copy components from more than one instance")
		elseif #selected == 0 then
			error("No instance selected")
		end

		componentClipboard = {}

		local state = store:getState()
		local openMenus = state.ComponentMenu
		local components = ComponentManager.Get().components

		for _, component in ipairs(components) do
			if not openMenus[component.Name] then
				continue
			end

			local _, value = next(component.Values)

			if value then
				componentClipboard[component] = value
			end
		end

		print(componentClipboard)
	end

	local function pasteComponents()
		for component, value in pairs(componentClipboard) do
			ComponentManager.Get():SetComponent(component, true, value)
		end
	end

	local manager = ComponentManager.new(store)

	local worldViewConnection = worldViewButton.Click:Connect(function()
		local state = store:getState()
		local newValue = not state.WorldView
		store:dispatch(Actions.ToggleWorldView(newValue))
		worldViewButton:SetActive(newValue)
	end)

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 0, 0)
	local gui = plugin:createDockWidgetPluginGui("ComponentEditor" .. nameSuffix, info)
	gui.Name = "ComponentEditor" .. nameSuffix
	gui.Title = "Component Editor" .. displaySuffix
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	toggleButton:SetActive(gui.Enabled)

	local connection = toggleButton.Click:Connect(function()
		gui.Enabled = not gui.Enabled
		toggleButton:SetActive(gui.Enabled)
	end)

	local pasteConnection = pasteButton.Click:Connect(pasteComponents)
	local copyConnection = copyButton.Click:Connect(copyComponents)

	local prefix = "ComponentEditor" .. nameSuffix .. "_"

	local changeIconAction = plugin:createAction(
		prefix .. "ChangeIcon",
		"Change icon...",
		"Change the icon of the component."
	)

	local changeGroupAction = plugin:createAction(
		prefix .. "ChangeGroup",
		"Change group...",
		"Change the sorting group of the component."
	)

	local changeColorAction = plugin:createAction(
		prefix .. "ChangeColor",
		"Change color...",
		"Change the color of the component."
	)

	local renameAction = plugin:createAction(
		prefix .. "Rename",
		"Rename",
		"Rename the component, updating every entity currently possessing it."
	)

	local deleteAction = plugin:createAction(
		prefix .. "Delete",
		"Delete",
		"Delete the component and remove it from all instances.",
		nil,
		false
	)

	local viewComponentizedAction = plugin:createAction(
		prefix .. "ViewComponentized",
		"View linked instances",
		"Show a list of instances that have this component.",
		nil,
		false
	)

	local selectAllAction: PluginAction = plugin:createAction(
		prefix .. "SelectAll",
		"Select all",
		"Select all instances with this component."
	)

	local selectAllConn = selectAllAction.Triggered:Connect(function()
		local state = store:getState()
		local component = state.InstanceView or PluginGlobals.currentComponentMenu or state.ComponentMenu

		if component then
			ComponentManager.Get():SelectAll(component.Definition.name)
		end
	end)

	local copyAction = plugin:createAction(
		prefix .. "CopyComponents",
		"Copy components",
		"Copy components from a selected instance."
	)

	local copyActionConnection = copyAction.Triggered:Connect(copyComponents)

	local pasteAction = plugin:createAction(
		prefix .. "PasteComponents",
		"Paste components",
		"Paste currently copied components onto selected instances."
	)

	local pasteActionConnection = pasteAction.Triggered:Connect(pasteComponents)

	local visualizeBox = plugin:createAction(
		prefix .. "Visualize_Box",
		"Box",
		"Render this component as a box when the overlay is enabled.",
		nil,
		false
	)

	local visualizeSphere = plugin:createAction(
		prefix .. "Visualize_Sphere",
		"Sphere",
		"Render this component as a sphere when the overlay is enabled.",
		nil,
		false
	)

	local visualizeOutline = plugin:createAction(
		prefix .. "Visualize_Outline",
		"Outline",
		"Render this component as an outline around parts when the overlay is enabled.",
		nil,
		false
	)

	local visualizeText = plugin:createAction(
		prefix .. "Visualize_Text",
		"Text",
		"Render this component as a floating text label when the overlay is enabled.",
		nil,
		false
	)

	local visualizeIcon = plugin:createAction(
		prefix .. "Visualize_Icon",
		"Icon",
		"Render the component's icon when the overlay is enabled.",
		nil,
		false
	)

	local visualizeMenu: PluginMenu = plugin:createMenu(prefix .. "ComponentMenu_VisualizeAs", "Change draw mode")
	visualizeMenu:AddAction(visualizeBox)
	visualizeMenu:AddAction(visualizeSphere)
	visualizeMenu:AddAction(visualizeOutline)
	visualizeMenu:AddAction(visualizeText)
	visualizeMenu:AddAction(visualizeIcon)

	local componentMenu: PluginMenu = plugin:createMenu(prefix .. "ComponentMenu")
	componentMenu:AddAction(viewComponentizedAction)
	componentMenu:AddAction(selectAllAction)
	componentMenu:AddMenu(visualizeMenu)
	componentMenu:AddSeparator()
	componentMenu:AddAction(changeIconAction)
	componentMenu:AddAction(changeColorAction)
	componentMenu:AddAction(changeGroupAction)

	PluginGlobals.ComponentMenu = componentMenu
	PluginGlobals.changeIconAction = changeIconAction
	PluginGlobals.changeGroupAction = changeGroupAction
	PluginGlobals.changeColorAction = changeColorAction
	PluginGlobals.renameAction = renameAction
	PluginGlobals.deleteAction = deleteAction
	PluginGlobals.selectAllAction = selectAllAction
	PluginGlobals.viewComponentizedAction = viewComponentizedAction
	PluginGlobals.visualizeBox = visualizeBox
	PluginGlobals.visualizeSphere = visualizeSphere
	PluginGlobals.visualizeOutline = visualizeOutline
	PluginGlobals.visualizeText = visualizeText
	PluginGlobals.visualizeIcon = visualizeIcon

	local element = Roact.createElement(RoactRodux.StoreProvider, {
		store = store,
	}, {
		App = Roact.createElement(App, {
			root = gui,
		}),
	})

	local instance = Roact.mount(element, gui, "ComponentEditor")

	plugin:beforeUnload(function()
		Roact.unmount(instance)
		connection:Disconnect()
		copyActionConnection:Disconnect()
		copyConnection:Disconnect()
		pasteActionConnection:Disconnect()
		pasteConnection:Disconnect()
		worldViewConnection:Disconnect()
		manager:Destroy()
		selectAllConn:Disconnect()
		return store:getState()
	end)
end
