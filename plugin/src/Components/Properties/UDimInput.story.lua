local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)

local UDimInput = require(script.Parent.UDimInput)

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
			UDimInput = Roact.createElement(UDimInput, {
				Key = "What is a UDim?",
				Value = UDim.new(0.4, 25),
				OnChanged = function(udim)
					print(udim)
				end
			})
		}),
	})

	local handle = Roact.mount(element, target)
	return function()
		Roact.unmount(handle)
	end
end
