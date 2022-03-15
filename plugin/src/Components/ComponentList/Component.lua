local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)
local Actions = require(Modules.Plugin.Actions)
local ComponentManager = require(Modules.Plugin.ComponentManager)
local Item = require(Modules.Plugin.Components.ListItem)
local ComponentValues = require(Modules.Plugin.Components.ComponentList.ComponentValues)
local StudioThemeAccessor = require(Modules.Plugin.Components.StudioThemeAccessor)
local Util = require(Modules.Plugin.Util)
local PluginGlobals = require(Modules.Plugin.PluginGlobals)

local VerticalExpandingList = require(Modules.StudioComponents.VerticalExpandingList)

local Component = Roact.Component:extend("Component")

function Component:init()
	self:setState({
		isMenuOpen = false,
	})
end

function Component:render()
	local props = self.props
	local checked = nil

	if not props.Disabled then
		if props.HasAll then
			checked = true
		elseif props.HasSome then
			checked = "ambiguous"
		else
			checked = false
		end
	end

	local function openMenu(_rbx)
		if not checked then
			return
		end

		local isMenuOpen = self.state.isMenuOpen

		if not isMenuOpen then
			props.openComponentMenu(props.Component)
		else
			props.openComponentMenu(nil)
		end

		self:setState({
			isMenuOpen = not isMenuOpen,
		})
	end

	return StudioThemeAccessor.withTheme(function(theme)
		return Roact.createElement(VerticalExpandingList, { LayoutOrder = props.LayoutOrder, BorderSizePixel = 0 }, {
			Roact.createElement(Item, {
				Text = Util.escapeComponentName(props.Component.Name, theme),
				RichText = true,
				Icon = props.Icon,
				IsInput = props.isBeingRenamed,
				ClearTextOnFocus = false,
				CaptureFocusOnBecomeInput = true,
				TextBoxText = props.Component,
				Visible = props.Visible,
				Checked = checked,
				Active = checked and self.state.isMenuOpen,
				Hidden = props.Hidden,
				Indent = props.Group and 10 or 0,
				Height = 26,

				onSetVisible = function()
					ComponentManager.Get():SetVisible(props.Definition, not props.Visible)
				end,

				onCheck = function(_rbx)
					ComponentManager.Get():SetComponent(props.Component, not props.HasAll)
				end,

				onSubmit = function(_rbx, newName)
					props.stopRenaming()
					ComponentManager.Get():Rename(props.Component, newName)
				end,

				onFocusLost = props.stopRenaming,
				leftClick = openMenu,
				rightClick = function(_rbx)
					props.showContextMenu(props.Component)
				end,
			}),
			(checked and self.state.isMenuOpen) and Roact.createElement(ComponentValues, {
				Definition = props.Definition,
				Values = props.Values,
			}),
		})
	end)
end

local function mapStateToProps(state, props)
	return {
		isMenuOpen = state.ComponentMenu == props.Component,
		isBeingRenamed = state.RenamingComponent == props.Component,
	}
end

local function mapDispatchToProps(dispatch)
	return {
		openComponentMenu = function(component)
			dispatch(Actions.OpenComponentMenu(component))
		end,
		showContextMenu = function(component)
			PluginGlobals.showComponentMenu(dispatch, component)
		end,
		stopRenaming = function(component)
			dispatch(Actions.SetRenaming(component, false))
		end,
	}
end

Component = RoactRodux.connect(mapStateToProps, mapDispatchToProps)(Component)

return Component
