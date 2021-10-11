local Modules = script.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)
local Constants = require(Modules.Plugin.Constants)
local Actions = require(Modules.Plugin.Actions)
local ComponentManager = require(Modules.Plugin.ComponentManager)
local Util = require(Modules.Plugin.Util)

local Item = require(script.Parent.ListItem)
local Component = require(script.Component)
local Group = require(script.Group)
local ScrollFrame = require(Modules.StudioComponents.ScrollFrame)
local StudioThemeAccessor = require(Modules.Plugin.Components.StudioThemeAccessor)

local ComponentList = Roact.PureComponent:extend("ComponentList")

function ComponentList:render()
	local props = self.props

	local function toggleGroup(group)
		self:setState({
			["Hide" .. group] = not self.state["Hide" .. group],
		})
	end

	local components = props.Components
	table.sort(components, function(a, b)
		local ag = a.Group or ""
		local bg = b.Group or ""
		if ag < bg then
			return true
		end
		if bg < ag then
			return false
		end

		local an = a.Name or ""
		local bn = b.Name or ""

		return an < bn
	end)

	local children = {}

	local lastGroup
	local itemCount = 1
	for i = 1, #components do
		local groupName = components[i].Group or "Default"
		if components[i].Group ~= lastGroup then
			lastGroup = components[i].Group
			children["Group" .. groupName] = Roact.createElement(Group, {
				Name = groupName,
				LayoutOrder = itemCount,
				toggleHidden = toggleGroup,
				Hidden = self.state["Hide" .. groupName],
			})
			itemCount = itemCount + 1
		end
		children[components[i].Name] = Roact.createElement(
			Component,
			Util.merge(components[i], {
				Hidden = self.state["Hide" .. groupName],
				Disabled = not props.selectionActive,
				Component = components[i].Name,
				LayoutOrder = itemCount,
			})
		)
		itemCount = itemCount + 1
	end

	local unknownComponents = props.unknownComponents

	for i = 1, #unknownComponents do
		local component = unknownComponents[i]
		children[component] = StudioThemeAccessor.withTheme(function(theme)
			return Roact.createElement(Item, {
				Text = string.format(
					"%s (click to import)",
					Util.escapeComponentName(component, theme)
				),
				RichText = true,
				Icon = "help",
				ButtonColor = Constants.LightRed,
				LayoutOrder = itemCount,
				TextProps = {
					Font = Enum.Font.SourceSansItalic,
				},

				leftClick = function(_rbx)
					ComponentManager.Get():AddComponent(component)
				end,
			})
		end)
		itemCount = itemCount + 1
	end

	if #components == 0 then
		children.NoResults = Roact.createElement(Item, {
			LayoutOrder = itemCount,
			Text = "No search results found.",
			Icon = "cancel",
			TextProps = {
				Font = Enum.Font.SourceSansItalic,
			},
		})
		itemCount = itemCount + 1
	end

	return Roact.createElement(ScrollFrame, {
		Size = props.Size or UDim2.new(1, 0, 1, 0),
		Layout = {
			ClassName = "UIListLayout",
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 1),
		},
	}, children)
end

local function mapStateToProps(state)
	local components = {}

	for _, component in pairs(state.ComponentData) do
		-- todo: LCS
		local passSearch = not state.Search
			or component.Name:lower():find(state.Search:lower(), 1, true)
		if passSearch then
			components[#components + 1] = component
		end
	end

	local unknownComponents = {}
	for _, component in pairs(state.UnknownComponents) do
		-- todo: LCS
		local passSearch = not state.Search or component:lower():find(state.Search:lower(), 1, true)
		if passSearch then
			unknownComponents[#unknownComponents + 1] = component
		end
	end

	return {
		Components = components,
		searchTerm = state.Search,
		unknownComponents = unknownComponents,
		selectionActive = state.SelectionActive,
	}
end

local function mapDispatchToProps(dispatch)
	return {
		setSearch = function(term)
			dispatch(Actions.SetSearch(term))
		end,
	}
end

ComponentList = RoactRodux.connect(mapStateToProps, mapDispatchToProps)(ComponentList)

return ComponentList
