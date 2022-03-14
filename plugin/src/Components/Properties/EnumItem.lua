local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local StudioComponents = require(Modules.StudioComponents)

local BaseProperty = require(script.Parent.BaseProperty)

local EnumItem = Roact.Component:extend("EnumItem")

function EnumItem:render()
	local props = self.props
	local items = {}

	for _, enumItem in ipairs(props.Enum:GetEnumItems()) do
		table.insert(items, enumItem.Name)
	end

	print(self.state)

	return Roact.createElement(BaseProperty, {
		Text = props.Key,
		ZIndex = 100,
	}, {
		Centered = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 15),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
		}, {
			Dropdown = Roact.createElement(StudioComponents.Dropdown, {
				Items = items,
				Item = if self.state.selected then self.state.selected else props.Selected.Name,
				OnSelected = function(enumItemName)
					local item = props.Enum[enumItemName]

					props.OnSelected(item)

					self:setState({
						selected = item,
					})
				end,
			}),
		}),
	})
end

return EnumItem
