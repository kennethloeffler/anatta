local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local StudioComponents = require(Modules.StudioComponents)

local BaseProperty = require(script.Parent.BaseProperty)

local function EnumItem(props)
	local items = {}

	for _, enumItem in ipairs(props.Enum:GetEnumItems()) do
		table.insert(items, enumItem.Name)
	end

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
				Item = props.Selected.Name,
				OnSelected = function(enumItemName)
					local item = props.Enum[enumItemName]
					props.OnSelected(item)
				end,
			}),
		}),
	})
end

return EnumItem
