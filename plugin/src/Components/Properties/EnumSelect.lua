local Modules = script.Parent.Parent.Parent.Parent
local Roact = require(Modules.Roact)
local StudioComponents = require(Modules.StudioComponents)

local BaseProperty = require(script.Parent.BaseProperty)

local function EnumSelect(props)
	local items = {}

	for _, enum in ipairs(Enum:GetEnums()) do
		table.insert(items, tostring(enum))
	end

	return Roact.createElement(BaseProperty, {
		LayoutOrder = props.LayoutOrder,
		Text = props.Key,
	}, {
		Centered = Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 15),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
		}, {
			Dropdown = Roact.createElement(StudioComponents.Dropdown, {
				Items = items,
				Item = tostring(props.Selected),
				OnSelected = function(enumName)
					props.OnSelected(Enum[enumName])
				end,
			}),
		}),
	})
end

return EnumSelect
