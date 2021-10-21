local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)

local UDim2Input = require(script.Parent.UDim2Input)

return function(target)
	local element = Roact.createFragment({
		Layout = Roact.createElement("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.Name,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Container = Roact.createElement("Frame", {
			LayoutOrder = 0,
			Size = UDim2.fromOffset(300, 25),
			BackgroundTransparency = 1,
		}, {
			UDimInput = Roact.createElement(UDim2Input, {
				Key = "2D UDiiiiim?",
				Value = UDim2.new(0.4, 25, 0.3, 400),
				OnChanged = function(udim2)
					print(udim2)
				end
			})
		}),
	})

	local handle = Roact.mount(element, target)
	return function()
		Roact.unmount(handle)
	end
end
