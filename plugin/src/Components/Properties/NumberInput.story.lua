local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)

local NumberInput = require(script.Parent.NumberInput)

return function(target)
	local element = Roact.createFragment({
		Layout = Roact.createElement("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.Name,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Container0 = Roact.createElement("Frame", {
			LayoutOrder = 0,
			Size = UDim2.fromOffset(300, 25),
			BackgroundTransparency = 1,
		}, {
			NumberInput = Roact.createElement(NumberInput, {
				Key = "Cool Number Bro",
				Value = 55,
				OnChanged = function()
					
				end
			}),
		}),
		Container1 = Roact.createElement("Frame", {
			LayoutOrder = 0,
			Size = UDim2.fromOffset(300, 25),
			BackgroundTransparency = 1,
		}, {
			NumberMinInput = Roact.createElement(NumberInput, {
				Key = "Minimum -10",
				Value = 55,
				OnChanged = function()
					
				end,
				Min = -10,
			}),
		}),
		Container2 = Roact.createElement("Frame", {
			LayoutOrder = 0,
			Size = UDim2.fromOffset(300, 25),
			BackgroundTransparency = 1,
		}, {
			NumberMaxInput = Roact.createElement(NumberInput, {
				Key = "Maximum 8999",
				Value = 299,
				OnChanged = function()
					
				end,
				Max = 8999,
			}),
		}),
		Container3 = Roact.createElement("Frame", {
			LayoutOrder = 0,
			Size = UDim2.fromOffset(300, 25),
			BackgroundTransparency = 1,
		}, {
			NumberConstrainedInput = Roact.createElement(NumberInput, {
				Key = "Constrainted 0-1",
				Value = 0.2,
				OnChanged = function()
					
				end,
				Min = 0,
				Max = 1,
			}),
		}),
	})

	local handle = Roact.mount(element, target)
	return function()
		Roact.unmount(handle)
	end
end
