local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)
local ComponentManager = require(Modules.Plugin.ComponentManager)
local Actions = require(Modules.Plugin.Actions)
local Item = require(Modules.Plugin.Components.ListItem)

local function GroupItem(props)
	return Roact.createElement(Item, {
		Icon = "folder",
		Text = props.Name,
		Active = props.Active,
		LayoutOrder = props.LayoutOrder,

		leftClick = function(_rbx)
			ComponentManager.Get():SetGroup(props.Component, props.Group)
			props.close()
		end,

		onDelete = props.Group and function()
			props.delete(props.Group)
		end or nil,
	})
end

local function mapStateToProps(state)
	return {
		Component = state.GroupPicker,
	}
end

local function mapDispatchToProps(dispatch)
	return {
		close = function()
			dispatch(Actions.ToggleGroupPicker(nil))
		end,
		delete = function(name)
			ComponentManager.Get():DelGroup(name)
		end,
	}
end

GroupItem = RoactRodux.connect(mapStateToProps, mapDispatchToProps)(GroupItem)

return GroupItem
