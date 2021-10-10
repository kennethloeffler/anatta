local Search = require(script.Search)
local IconSearch = require(script.IconSearch)
local ComponentMenu = require(script.ComponentMenu)
local ComponentData = require(script.ComponentData)
local UnknownComponents = require(script.UnknownComponents)
local GroupData = require(script.GroupData)
local IconPicker = require(script.IconPicker)
local ColorPicker = require(script.ColorPicker)
local GroupPicker = require(script.GroupPicker)
local WorldView = require(script.WorldView)
local Dropdown = require(script.Dropdown)
local InstanceView = require(script.InstanceView)
local HoveredIcon = require(script.HoveredIcon)
local SelectionActive = require(script.SelectionActive)
local RenamingComponent = require(script.RenamingComponent)

return function(state, action)
	state = state or {}
	return {
		IconSearch = IconSearch(state.IconSearch, action),
		Search = Search(state.Search, action),
		ComponentMenu = ComponentMenu(state.ComponentMenu, action),
		ComponentData = ComponentData(state.ComponentData, action),
		UnknownComponents = UnknownComponents(state.UnknownComponents, action),
		GroupData = GroupData(state.GroupData, action),
		IconPicker = IconPicker(state.IconPicker, action),
		ColorPicker = ColorPicker(state.ColorPicker, action),
		GroupPicker = GroupPicker(state.GroupPicker, action),
		WorldView = WorldView(state.WorldView, action),
		Dropdown = Dropdown(state.Dropdown, action),
		InstanceView = InstanceView(state.InstanceView, action),
		HoveredIcon = HoveredIcon(state.HoveredIcon, action),
		SelectionActive = SelectionActive(state.SelectionActive, action),
		RenamingComponent = RenamingComponent(state.RenamingComponent, action),
	}
end
