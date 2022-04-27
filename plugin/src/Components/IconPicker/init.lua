local Modules = script.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)
local Actions = require(Modules.Plugin.Actions)

local Page = require(script.Parent.Page)
local Search = require(script.Parent.Search)
local Preview = require(script.Preview)
local IconsPage = require(script.IconsPage)
local EmojiPage = require(script.EmojiPage)
local CustomPage = require(script.CustomPage)
local StudioThemeAccessor = require(Modules.Plugin.Components.StudioThemeAccessor)
local TabLayout = require(Modules.Plugin.Components.TabLayout)

local IconPicker = Roact.PureComponent:extend("IconPicker")

function IconPicker:init()
	self.closeFunc = function()
		self.props.close()
	end
	self.onHoverFunc = function(icon)
		self.props.setHoveredIcon(icon)
	end
end

function IconPicker:shouldUpdate(newProps)
	return self.props.componentName ~= newProps.componentName or self.props.search ~= newProps.search
end

function IconPicker:render()
	local props = self.props

	return Roact.createElement(Page, {
		visible = props.componentName ~= nil,
		title = tostring(props.componentName) .. " - Select an Icon",
		titleIcon = props.componentIcon,

		close = function()
			props.close()
		end,
	}, {
		TabLayout = Roact.createElement(TabLayout, {
			Size = UDim2.new(1, 0, 1, -64),
			Position = UDim2.new(0, 0, 0, 64),
			tabs = {
				{
					name = "Icons",
					render = function()
						return Roact.createElement(IconsPage, {
							componentName = props.componentName,
							search = props.search,
							closeFunc = self.closeFunc,
							onHoverFunc = self.onHoverFunc,
						})
					end,
				},
				{
					name = "Emoji",
					render = function()
						return Roact.createElement(EmojiPage, {
							componentName = props.componentName,
							search = props.search,
							closeFunc = self.closeFunc,
							onHoverFunc = self.onHoverFunc,
						})
					end,
				},
				{
					name = "Custom",
					render = function()
						return Roact.createElement(CustomPage, {
							componentName = props.componentName,
							search = props.search,
							closeFunc = self.closeFunc,
							onHoverFunc = self.onHoverFunc,
						})
					end,
				},
			},
		}),
		TopBar = StudioThemeAccessor.withTheme(function(theme)
			return Roact.createElement("Frame", {
				BackgroundColor3 = theme:GetColor("Titlebar"),
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 64),
				ZIndex = 2,
			}, {
				Search = Roact.createElement(Search, {
					Size = UDim2.new(1, -56, 0, 40),
					Position = UDim2.new(0, 56, 0, 0),

					term = props.search,
					setTerm = function(term)
						props.setTerm(term)
					end,
				}),
				Preview = Roact.createElement(Preview, {
					Position = UDim2.new(0, 8, 0, 8),
				}),
				Separator = Roact.createElement("Frame", {
					-- This separator acts as a bottom border, so we should use the border color, not the separator color
					BackgroundColor3 = theme:GetColor("Border"),
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					AnchorPoint = Vector2.new(0, 1),
					ZIndex = 2,
				}),
			})
		end),
	})
end

local function mapStateToProps(state, props)
	local componentName = state.IconPicker
	local componentIcon
	for _, component in pairs(state.ComponentData) do
		if component.Name == componentName then
			componentIcon = component.Icon
			break
		end
	end

	return {
		componentName = componentName,
		componentIcon = componentIcon,
		search = state.IconSearch,
	}
end

local function mapDispatchToProps(dispatch)
	return {
		close = function()
			dispatch(Actions.ToggleIconPicker(nil))
		end,

		setTerm = function(term)
			dispatch(Actions.SetIconSearch(term))
		end,

		setHoveredIcon = function(icon)
			dispatch(Actions.SetHoveredIcon(icon))
		end,
	}
end

IconPicker = RoactRodux.connect(mapStateToProps, mapDispatchToProps)(IconPicker)

return IconPicker
