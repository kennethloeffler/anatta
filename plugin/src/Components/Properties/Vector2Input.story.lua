local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)

local Vector2Input = require(script.Parent.Vector2Input)

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
			Vector2Input = Roact.createElement(Vector2Input, {
				Key = "Whoa, I'm in 2D",
				Value = Vector2.new(-1, 55),
				OnChanged = function(vec2)
					print(vec2)
				end,
			}),
		}),
	})

	local handle = Roact.mount(element, target)
	return function()
		Roact.unmount(handle)
	end
end
