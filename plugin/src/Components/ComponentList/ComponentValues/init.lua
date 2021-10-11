local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)
local Actions = require(Modules.Plugin.Actions)
local ComponentManager = require(Modules.Plugin.ComponentManager)
local PluginGlobals = require(Modules.Plugin.PluginGlobals)

local Button = require(Modules.Plugin.Components.Button)
local Checkbox = require(Modules.Plugin.Components.Checkbox)
local TextLabel = require(Modules.Plugin.Components.ThemedTextLabel)
local DeleteButton = require(script.DeleteButton)
local StudioThemeAccessor = require(Modules.Plugin.Components.StudioThemeAccessor)
local Dropdown = require(Modules.Plugin.Components.Dropdown)

local function ComponentSettings(props)
	return Roact.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
	}, {
		SideButtons = Roact.createElement("Frame", {
			Size = UDim2.new(0.4, 0, 1, 0),
			BackgroundTransparency = 1,
		}, {
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
				PaddingLeft = UDim.new(0, 5),
			}),
			Layout = Roact.createElement("UIListLayout", {
				SortOrder = "LayoutOrder",
				HorizontalAlignment = "Center",
				FillDirection = "Vertical",
				VerticalAlignment = "Top",
				Padding = UDim.new(0, 5),
			}),
			ChangeIcon = Roact.createElement(Button, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 30),
				Text = "Change icon",
				leftClick = function()
					props.iconPicker(props.componentMenu)
				end,
			}),
			ChangeGroup = Roact.createElement(Button, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 30),
				Text = "Change group",
				leftClick = function()
					props.groupPicker(props.componentMenu)
				end,
			}),
			Entities = Roact.createElement(Button, {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 30),
				Text = "Entities",
				leftClick = function()
					props.instanceView(props.componentMenu)
				end,
			}),
			Delete = Roact.createElement(DeleteButton, {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 30),
				Text = "Delete",
				leftClick = function()
					ComponentManager.Get():DelComponent(props.componentMenu)
					props.close()
				end,
			}),
		}),
		Visualization = Roact.createElement("Frame", {
			Size = UDim2.new(0.6, -10, 1, 0),
			Position = UDim2.new(1, -5, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
		}, {
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
				PaddingLeft = UDim.new(0, 5),
			}),
			Layout = Roact.createElement("UIListLayout", {
				Padding = UDim.new(0, 5),
				SortOrder = "LayoutOrder",
			}),
			Title = Roact.createElement(TextLabel, {
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = 1,
				Text = "Component Visualization",
				TextSize = 20,
			}),
			ChangeColor = Roact.createElement(Button, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 30),
				Text = "Change color",
				leftClick = function()
					props.colorPicker(props.componentMenu)
				end,
			}, {
				ColorVisualization = StudioThemeAccessor.withTheme(function(theme)
					return Roact.createElement("Frame", {
						Size = UDim2.new(1, -10, 1, -10),
						Position = UDim2.new(1, -5, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundColor3 = props.componentColor,
						BorderColor3 = theme:GetColor("Border"),
					}, {
						ARConstraint = Roact.createElement("UIAspectRatioConstraint", {
							AspectRatio = 1,
							DominantAxis = "Height",
						}),
					})
				end),
			}),
			AlwaysOnTop = Roact.createElement("ImageButton", {
				LayoutOrder = 3,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0, 0, 0, 40),
				[Roact.Event.MouseButton1Click] = function()
					ComponentManager.Get():SetAlwaysOnTop(
						props.componentMenu,
						not props.componentAlwaysOnTop
					)
				end,
			}, {
				Padding = Roact.createElement("UIPadding", {
					PaddingTop = UDim.new(0, 5),
					PaddingBottom = UDim.new(0, 5),
				}),
				Check = Roact.createElement(Checkbox, {
					Checked = props.componentAlwaysOnTop,
					leftClick = function()
						ComponentManager.Get():SetAlwaysOnTop(
							props.componentMenu,
							not props.componentAlwaysOnTop
						)
					end,
				}),
				Label = Roact.createElement(TextLabel, {
					Size = UDim2.new(1, -30, 1, 0),
					Position = UDim2.new(0, 30, 0, 0),
					Text = "Always on top",
					TextSize = 16,
				}),
			}),
			VisualizationKind = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				LayoutOrder = 4,
			}, {
				Layout = Roact.createElement("UIListLayout", {
					SortOrder = "LayoutOrder",
					FillDirection = "Horizontal",
					VerticalAlignment = "Center",
					Padding = UDim.new(0, 5),
				}),
				Label = Roact.createElement(TextLabel, {
					Text = "Visualize as:",
					LayoutOrder = 1,
					TextSize = 16,
				}),
				Dropdown = Roact.createElement(Dropdown, {
					LayoutOrder = 2,
					Size = UDim2.new(1, -75, 0, 30),
					Options = {
						"None",
						"Icon",
						"Outline",
						"Box",
						"Sphere",
						"Text",
					},
					CurrentOption = props.componentDrawType,
					onOptionSelected = function(option)
						ComponentManager.Get():SetDrawType(props.componentMenu, option)
					end,
				}),
			}),
		}),
	})
end

local function mapStateToProps(state)
	local icon
	local drawType
	local color
	local alwaysOnTop = false
	for _, v in pairs(state.ComponentData) do
		if v.Name == state.ComponentMenu then
			icon = v.Icon
			drawType = v.DrawType or "Box"
			color = v.Color
			alwaysOnTop = v.AlwaysOnTop
		end
	end

	return {
		componentMenu = state.ComponentMenu,
		componentIcon = icon or "component_green",
		componentColor = color,
		componentDrawType = drawType,
		componentAlwaysOnTop = alwaysOnTop,
	}
end

local function mapDispatchToProps(dispatch)
	return {
		close = function()
			dispatch(Actions.OpenComponentMenu(nil))
		end,
		iconPicker = function(componentMenu)
			dispatch(Actions.ToggleIconPicker(componentMenu))
		end,
		colorPicker = function(componentMenu)
			PluginGlobals.promptPickColor(dispatch, componentMenu)
		end,
		groupPicker = function(componentMenu)
			dispatch(Actions.ToggleGroupPicker(componentMenu))
		end,
		instanceView = function(componentMenu)
			dispatch(Actions.OpenInstanceView(componentMenu))
		end,
	}
end

ComponentSettings = RoactRodux.connect(mapStateToProps, mapDispatchToProps)(ComponentSettings)

return ComponentSettings
