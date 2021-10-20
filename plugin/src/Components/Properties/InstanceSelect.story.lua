local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)

local InstanceSelect = require(script.Parent.InstanceSelect)

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
			InstanceSelect = Roact.createElement(InstanceSelect, {
				Key = "Favorite instance?",
				OnChanged = function(instance)
					print(instance:GetFullName())
				end,
				Instance = game:GetService("Workspace").Terrain
			})
		}),
	})

	local handle = Roact.mount(element, target)
	return function()
		Roact.unmount(handle)
	end
end
