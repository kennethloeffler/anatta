local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)

local Vector3Input = require(script.Parent.Vector3Input)

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
			Vector3Input = Roact.createElement(Vector3Input, {
				Key = "Whoa, I'm in 3D",
				Value = Vector3.new(-1, 55, 4),
				OnChanged = function(vec3)
					print(vec3)
				end,
			}),
		}),
	})

	local handle = Roact.mount(element, target)
	return function()
		Roact.unmount(handle)
	end
end
