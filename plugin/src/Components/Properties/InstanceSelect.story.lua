local Vendor = script.Parent.Parent.Parent.Parent
local Roact = require(Vendor.Roact)

local InstanceSelect = require(script.Parent.InstanceSelect)

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
			InstanceSelect = Roact.createElement(InstanceSelect, {
				Key = "Any Instance",
				OnChanged = function(instance)
					print(instance:GetFullName())
				end,
				Instance = game:GetService("Workspace").Camera
			})
		}),
		Container1 = Roact.createElement("Frame", {
			LayoutOrder = 0,
			Size = UDim2.fromOffset(300, 25),
			BackgroundTransparency = 1,
		}, {
			InstanceSelect = Roact.createElement(InstanceSelect, {
				Key = "IsA BasePart",
				IsA = "BasePart",
				OnChanged = function(instance)
					print(instance:GetFullName())
				end,
				Instance = game:GetService("Workspace").Terrain
			})
		}),
		Container2 = Roact.createElement("Frame", {
			LayoutOrder = 0,
			Size = UDim2.fromOffset(300, 25),
			BackgroundTransparency = 1,
		}, {
			InstanceSelect = Roact.createElement(InstanceSelect, {
				Key = "Class = ServerStorage",
				ClassName = "ServerStorage",
				OnChanged = function(instance)
					print(instance:GetFullName())
				end,
				Instance = game:GetService("ServerStorage")
			})
		}),
	})

	local handle = Roact.mount(element, target)
	return function()
		Roact.unmount(handle)
	end
end
