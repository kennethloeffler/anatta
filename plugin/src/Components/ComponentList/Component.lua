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

		props.openComponentMenu(not isMenuOpen, props.Component)

		self:setState({
			isMenuOpen = not isMenuOpen,
		})
	end

	return StudioThemeAccessor.withTheme(function(theme)
		return Roact.createElement(
			VerticalExpandingList,
			{ LayoutOrder = props.LayoutOrder, BorderSizePixel = 0, ZIndex = props.ZIndex },
			{
				Item = Roact.createElement(Item, {
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
					LayoutOrder = 1,

					onSetVisible = function()
						ComponentManager.Get():SetVisible(props.Definition.name, not props.Visible)
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
				Values = (checked and self.state.isMenuOpen) and Roact.createElement(ComponentValues, {
					LayoutOrder = 2,
					Definition = props.Definition,
					ValuesFromInstance = props.ValuesFromInstance,
				}),
			}
		)
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
		openComponentMenu = function(isMenuOpen, component)
			dispatch(Actions.OpenComponentMenu(isMenuOpen, component))
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
