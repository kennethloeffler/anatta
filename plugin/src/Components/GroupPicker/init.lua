local Modules = script.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local RoactRodux = require(Modules.RoactRodux)
local Actions = require(Modules.Plugin.Actions)
local ComponentManager = require(Modules.Plugin.ComponentManager)
local Util = require(Modules.Plugin.Util)

local Page = require(script.Parent.Page)
local ScrollingFrame = require(script.Parent.ScrollingFrame)
local Item = require(script.Parent.ListItem)
local GroupItem = require(script.GroupItem)

local function GroupPicker(props)
	local children = {}

	children.UIPadding = Roact.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
	})

	children.Default = Roact.createElement(GroupItem, {
		Name = "Default",
		Group = nil,
		Active = props.componentGroup == nil,
		LayoutOrder = -1,
	})

	table.sort(props.groups)

	for i, group in pairs(props.groups) do
		children["Group " .. group] = Roact.createElement(GroupItem, {
			Name = group,
			Group = group,
			Active = props.componentGroup == group,
			LayoutOrder = i,
		})
	end

	children.AddNew = Roact.createElement(Item, {
		LayoutOrder = 99999999,
		Text = "Add new group...",
		Icon = "folder_add",
		IsInput = true,

		onSubmit = function(_rbx, text)
			ComponentManager.Get():SetGroup(props.groupPicker, text)
			props.close()
		end,
	})

	return Roact.createElement(Page, {
		visible = props.groupPicker ~= nil,
		title = tostring(props.groupPicker) .. " - Select a Group",
		titleIcon = props.componentIcon,

		close = props.close,
	}, {
		Body = Roact.createElement(ScrollingFrame, {
			Size = UDim2.new(1, 0, 1, 0),
			List = true,
		}, children),
	})
end

local function mapStateToProps(state)
	local component = state.GroupPicker
		and Util.findIf(state.ComponentData, function(item)
			return item.Name == state.GroupPicker
		end)

	return {
		groupPicker = state.GroupPicker,
		componentIcon = component and component.Icon or nil,
		componentGroup = component and component.Group or nil,
		groups = state.GroupData,
	}
end

local function mapDispatchToProps(dispatch)
	return {
		close = function()
			dispatch(Actions.ToggleGroupPicker(nil))
		end,
	}
end

GroupPicker = RoactRodux.connect(mapStateToProps, mapDispatchToProps)(GroupPicker)

return GroupPicker
