local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)

local InlineButton = require(script.Parent.InlineButton)

return function(target)
	local element = Roact.createFragment({
		Layout = Roact.createElement("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Container = Roact.createElement("Frame", {
			LayoutOrder = 0,
			Size = UDim2.fromOffset(300, 25),
			BackgroundTransparency = 1,
		}, {
			BaseProperty = Roact.createElement(InlineButton, {
				Text = "+ Add Item",
			}),
		}),
		Container1 = Roact.createElement("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(300, 25),
			BackgroundTransparency = 1,
		}, {
			BaseProperty = Roact.createElement(InlineButton, {
				Indents = 3,
				Text = "- Remove Item",
			}),
		}),
	})

	local handle = Roact.mount(element, target)
	return function()
		Roact.unmount(handle)
	end
end
